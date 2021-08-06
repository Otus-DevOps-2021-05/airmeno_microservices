# airmeno_microservices
airmeno microservices repository

## Docker - 2 

Установка Docker на хост - https://docs.docker.com/engine/install/ubuntu/

```
docker version
docker info
```

Команды Docker | Значение
------| ---------
docker run hello-world | Запустить контейнер
docker ps | Список запущенных контейнеров
docker ps -a | Список всех контейнеров
docker images | Список сохранненных образов
docker run -it ubuntu:18.04 /bin/bash | Запуск контейнера Ubuntu в интерактивной режиме, вход в контенер в bash
docker exec -it <u_container_id> bash | Вход в запущенный контейнер c id в bash
docker commit <u_container_id> airmeno/ubuntu-tmp-file | Создание собственного образа (image) из контейнера 
docker rm -v $(docker ps -aq -f status=exited) | Удаление остановленных контейнеров
docker rmi name |  Удаление образа
docker rmi $(docker images -q) --force | Удаление существующих образов полученных на хост
docker system df | Дискового пространства образов

### Создаем Docker machine

```
yc compute instance create \
  --name docker-host \
  --zone ru-central1-a \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
  --ssh-key ~/.ssh/appuser.pub
```
```
docker-machine create \
  --driver generic \
  --generic-ip-address=84.252.130.86 \
  --generic-ssh-user yc-user \
  --generic-ssh-key ~/.ssh/appuser \
  docker-host
```
Проверим:

```
docker-machine ls

NAME          ACTIVE   DRIVER    STATE     URL                        SWARM   DOCKER     ERRORS
docker-host   -        generic   Running   tcp://84.252.130.86:2376           v20.10.7   
```
Переключим docker на удаленный хост:

```
eval $(docker-machine env docker-host)
```
> Отключаемся от окружения docker - eval $(docker-machine env --unset)

Соберем структуру файлов с требуемым содержанием и соберем образ и запусим наш контейнер из нашего образа:

```
docker build -t reddit:latest .
docker run --name reddit -d --network=host reddit:latest
```
Проверим:

```
docker-machine ls

NAME          ACTIVE   DRIVER    STATE     URL                        SWARM   DOCKER     ERRORS
docker-host   *        generic   Running   tcp://84.252.130.86:2376           v20.10.7 
```
Перейдем по адресу - http://84.252.130.86:9292

### Docker hub

Отправляем наш образ в docker репозиторий:

```
docker login

docker tag reddit:latest airmeno/otus-reddit:1.0
docker push airmeno/otus-reddit:1.0
```

Проверим:

```
docker run --name reddit -d -p 9292:9292 airmeno/otus-reddit:1.0
```

Удалим ресурсы:

```
docker-machine rm docker-host
yc compute instance delete docker-host
```

### Задания со ⭐

1. [docker-1.log](dockermonolit/docker-1.log)

2. Создаем в [docker-monolith/infra/](docker-monolith/infra/) аналогичную иерархию ветки `infra`.

При создании образа из Packer выполняется установка docker в образ c помощью плейбука `docker_install.yml`.

В Terraform количество создаваемых инстансов задается через переменную в `instance_count` в `terraform.tfvars`. 
Terraform генерирует на основе шаблона файл inventoy.ini для Ansible. 

Для запуска контейнера в инстансах в директории `ansible` запустить:
```
ansible-playbook playbooks/docker_run.yml
```

## Docker - 3

Поднимаем ранее созданный docker host:

```
yc compute instance create \
  --name docker-host \
  --zone ru-central1-a \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
  --ssh-key ~/.ssh/appuser.pub


docker-machine create \
  --driver generic \
  --generic-ip-address=84.201.159.37 \
  --generic-ssh-user yc-user \
  --generic-ssh-key ~/.ssh/appuser \
  docker-host


docker-machine ls
NAME          ACTIVE   DRIVER    STATE     URL                        SWARM   DOCKER     ERRORS
docker-host   -        generic   Running   tcp://84.201.159.37:2376           v20.10.8   


eval $(docker-machine env docker-host)
```

Скачиваем архив, распаковываем, удалем архив, переименовываем каталог и приводим файлы в требуемый вид.

Сборка приложения:

```
docker pull mongo:latest

docker build -t airmeno/post:1.0 ./post-py
docker build -t airmeno/comment:1.0 ./comment
docker build -t airmeno/ui:1.0 ./ui
```

Проверим наши образы:

```
docker images
```

Создаем специальную сеть для нашего приложения и проверим:

```
docker network create reddit

docker network ls 
```

Создаем бридж и запускаем контейнеры:

```
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest

docker run -d --network=reddit --network-alias=post airmeno/post:1.0
docker run -d --network=reddit --network-alias=comment airmeno/comment:1.0
docker run -d --network=reddit -p 9292:9292 airmeno/ui:1.0
```

### Задания со ⭐ (1)

Запуск контенеров с другими алиасами и передача данных с помощью переменных:

```
docker run -d --network=reddit --network-alias=my_post_db --network-alias=my_comment_db mongo:latest

docker run -d --network=reddit --network-alias=my_post --env POST_DATABASE_HOST=my_post_db airmeno/post:1.0
docker run -d --network=reddit --network-alias=my_comment --env COMMENT_DATABASE_HOST=my_comment_db  airmeno/comment:1.0
docker run -d --network=reddit -p 9292:9292 --env POST_SERVICE_HOST=my_post --env COMMENT_SERVICE_HOST=my_comment airmeno/ui:1.0
```

Были заданы алиасам название с `my_`  с переопределением перемнных `ENV` чрез ключ `--env`.

### Сервис ui - улучшаем образ

Посмотрим размер нашего образа `ui`:

```
docker images

REPOSITORY        TAG            IMAGE ID       CREATED          SIZE
airmeno/ui        1.0            3e640e60b8e3   30 minutes ago   771MB
```

Поменяем содержимое ./ui/Dockerfile:

```
FROM ubuntu:16.04
RUN apt-get update \
    && apt-get install -y ruby-full ruby-dev build-essential \
    && gem install bundler --no-ri --no-rdoc

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```

и пересоберем:

```
docker build -t airmeno/ui:2.0 ./ui
```

Проверим еще раз:

```
docker images

REPOSITORY        TAG            IMAGE ID       CREATED          SIZE
airmeno/ui        2.0            467ce10db702   24 seconds ago   462MB
airmeno/ui        1.0            3e640e60b8e3   36 minutes ago   771MB
```

Запустим еще раз наши контейнеры:

```
docker kill $(docker ps -q)
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest

docker run -d --network=reddit --network-alias=post airmeno/post:1.0
docker run -d --network=reddit --network-alias=comment airmeno/comment:1.0
docker run -d --network=reddit -p 9292:9292 airmeno/ui:2.0
```

### Создадим Docker volume

```
docker volume create reddit_db
```
Подключим его к контейнеру с MongoDB:

```
docker kill $(docker ps -q)
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest

docker run -d --network=reddit --network-alias=post airmeno/post:1.0
docker run -d --network=reddit --network-alias=comment airmeno/comment:1.0
docker run -d --network=reddit -p 9292:9292 airmeno/ui:2.0
```

### Задания со ⭐ (2)

Cобрать образ на основе Alpine Linux. Создаем [Dockerfile.1](src/ui/Dockerfile.1), в качестве базового образа берем Alpine Linux 3.14.
Для уменьшения размера образа используем `--no-cache` и после установки пакетов принудительно еще очищаем `rm -rf /var/cache/apk/*`.

Сборка нашего образа:

```
docker build -t airmeno/ui:3.0 ./ui --file ui/Dockerfile.1
```

Проверим еще раз размер образа:

```
docker images

REPOSITORY        TAG            IMAGE ID       CREATED          SIZE
airmeno/ui        3.0            f93530e5970f   35 seconds ago       265MB
airmeno/ui        2.0            467ce10db702   About an hour ago    462MB
airmeno/ui        1.0            3e640e60b8e3   About an hour ago    771MB
```

и проверим что наш образ рабочий:

```
docker kill $(docker ps -q)
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest

docker run -d --network=reddit --network-alias=post airmeno/post:1.0
docker run -d --network=reddit --network-alias=comment airmeno/comment:1.0
docker run -d --network=reddit -p 9292:9292 airmeno/ui:3.0
```

Удалим ресурсы:
```
docker-machine rm docker-host
yc compute instance delete docker-host
```
## Docker - 4

Поднимаем docker host:

```
yc compute instance create \
  --name docker-host \
  --zone ru-central1-a \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
  --ssh-key ~/.ssh/appuser.pub


docker-machine create \
  --driver generic \
  --generic-ip-address=84.252.130.206 \
  --generic-ssh-user yc-user \
  --generic-ssh-key ~/.ssh/appuser \
  docker-host


docker-machine ls
NAME          ACTIVE   DRIVER    STATE     URL                        SWARM   DOCKER     ERRORS
docker-host   -        generic   Running   tcp://84.252.130.206:2376           v20.10.8   


eval $(docker-machine env docker-host)
```

### Docker Network Drivers (Native)

* none - в контейнере есть только loopback интерфейс
* host - контейнеры видят только хостовувю сеть 
* bridge - контейнеры могу общаться через сеть и выходить наружу через хостовую сеть 

Запустим контейнеры с использованием драйверов сети с ключами --network: <none>, <host>, <bridge>

В качестве образа используем joffotron/docker-net-tools с сетевыми утилитами: bindtools, net-tools и curl.

```
docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

Вывод команды `docker-machine ssh docker-host ifconfig` бедет идентичен выводу `docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig`

```
docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig

docker0   Link encap:Ethernet  HWaddr 02:42:2C:69:21:67  
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

eth0      Link encap:Ethernet  HWaddr D0:0D:17:CA:5D:E8  
          inet addr:10.128.0.7  Bcast:10.128.0.255  Mask:255.255.255.0
          inet6 addr: fe80::d20d:17ff:feca:5de8%32666/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:10530 errors:0 dropped:0 overruns:0 frame:0
          TX packets:6844 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:117913818 (112.4 MiB)  TX bytes:606323 (592.1 KiB)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1%32666/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:282 errors:0 dropped:0 overruns:0 frame:0
          TX packets:282 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:25622 (25.0 KiB)  TX bytes:25622 (25.0 KiB)
```

```
docker run -ti --rm --network bridge joffotron/docker-net-tools -c ifconfig

eth0      Link encap:Ethernet  HWaddr 02:42:AC:11:00:02  
          inet addr:172.17.0.2  Bcast:172.17.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:2 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:180 (180.0 B)  TX bytes:0 (0.0 B)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

### Network namespaces

Запустим несколько раз (в моем случае 3 раза) команду `docker run --network host -d nginx`. Проверим наши контейнеры:

```
docker ps

CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS     NAMES
c8de1eb525ef   nginx     "/docker-entrypoint.…"   28 seconds ago   Up 25 seconds             flamboyant_swirles

docker ps -a
CONTAINER ID   IMAGE     COMMAND                  CREATED              STATUS                          PORTS     NAMES
35b31a75d59d   nginx     "/docker-entrypoint.…"   About a minute ago   Exited (1) About a minute ago             boring_bhaskara
76a8c0484020   nginx     "/docker-entrypoint.…"   About a minute ago   Exited (1) About a minute ago             jolly_thompson
c8de1eb525ef   nginx     "/docker-entrypoint.…"   2 minutes ago        Up About a minute                         flamboyant_swirles
```

Как видно из вывода, работает только один контейнер. Это связано с Host Driver:
- Контейнер использует network namespace хоста;
- Сеть не управляется самим Docker;
- Два сервиса в разных контейнерах не могут слушать один и тот же порт.

Подготовим хостовую машину для просмотра net-namespaces:

```
docker-machine ssh docker-host

sudo ln -s /var/run/docker/netns /var/run/netns
```

Теперь можно просматривать существующие network namespases: 
```
sudo ip netns 

default
```


Создадим docker-сети:
```
docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24
```

Запустим контейнеры:
```
docker build -t airmeno/post:1.0 ./post-py
docker build -t airmeno/comment:1.0 ./comment
docker build -t airmeno/ui:1.0 ./ui

docker run -d --network=front_net -p 9292:9292 --name ui airmeno/ui:1.0
docker run -d --network=back_net --name comment airmeno/comment:1.0
docker run -d --network=back_net --name post airmeno/post:1.0
docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest 
``` 

Docker при инициализации контейнера может подключить к нему только одну сеть. Дополнительные сети подключаются командой:
`docker network connect <network> <container>`

Подключим контейнеры ко второй сети:
```
docker network connect front_net post
docker network connect front_net comment
```

Заглянем внутрь сетей docker:

```
# Подключимся к докер хосту и установим утилиты для работы с бриджами
docker-machine ssh docker-host
sudo apt-get update && sudo apt-get install bridge-utils net-tools

sudo docker network ls

NETWORK ID     NAME        DRIVER    SCOPE
e49658e1166a   back_net    bridge    local
c6ce64b8682e   bridge      bridge    local
532d2c1a27d8   front_net   bridge    local
51ecc8068029   host        host      local
c4e2385e38fa   none        null      local

# созданные в рамках проекта сети
ifconfig | grep br

ifconfig | grep br
br-532d2c1a27d8: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.1.1  netmask 255.255.255.0  broadcast 10.0.1.255
br-e49658e1166a: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.2.1  netmask 255.255.255.0  broadcast 10.0.2.255
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        inet 10.128.0.7  netmask 255.255.255.0  broadcast 10.128.0.255

# Посмотрим какие интерфейсы есть в бридже
brctl show br-532d2c1a27d8

bridge name     bridge id               STP enabled     interfaces
br-532d2c1a27d8         8000.0242a651061f       no      veth1fccfd0
                                                        veth542d6b7
                                                        vethbc04562

# Посмотрим как выглядит iptables
sudo iptables -nL -t nat

...
Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
MASQUERADE  all  --  10.0.1.0/24          0.0.0.0/0           
MASQUERADE  all  --  10.0.2.0/24          0.0.0.0/0           
MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0           
MASQUERADE  tcp  --  10.0.1.2             10.0.1.2             tcp dpt:9292
...
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9292 to:10.0.1.2:9292

# проверим работу docker-proxy
ps ax | grep docker-proxy

19166 ?        Sl     0:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 9292 -container-ip 10.0.1.2 -container-port 9292
19173 ?        Sl     0:00 /usr/bin/docker-proxy -proto tcp -host-ip :: -host-port 9292 -container-ip 10.0.1.2 -container-port 9292
```

### Docker-compose

Docker-compose - это инструментальное средство взаимодействия контейнеров, docker сетей, хранилищ (volume). Удобен когда:
- Одно приложение состоит из множества контейнеров / сервисов
- Один контейнер зависит от другого
- Порядок запуска имеет значение
- docker build/run/create

Проверим установку:
```
docker-compose -v

docker-compose version 1.29.2, build 5becea4c
```

Остановим запущенные контейнеры:

```
docker kill $(docker ps -q)
```

Запустим docker-compose:

```
export USERNAME=airmeno
docker-compose up -d
```

Проверим:
```
docker-compose ps

    Name                  Command             State                    Ports                  
----------------------------------------------------------------------------------------------
src_comment_1   puma                          Up                                              
src_post_1      python3 post_app.py           Up                                              
src_post_db_1   docker-entrypoint.sh mongod   Up      27017/tcp                               
src_ui_1        puma                          Up      0.0.0.0:9292->9292/tcp,:::9292->9292/tcp
```

Параметризируем наш docker-compose.yml, переменные перенесем в `.env`, создадим алиасы сетей.

Зададим имя проекту, по умолчанию имя (префикс) формируется от имени каталога где находится проект, в нашем случае `src`. Для смены префикса можно запустить проект:

```
docker-compose -p project-name up -d
```

или задать переменную в `.env`: `COMPOSE_PROJECT_NAME=project-name`

### Задания со ⭐

- Изменять код каждого из приложений, не выполняя сборку образа 
- Запускать puma для руби приложений в дебаг режиме с двумя воркерами (флаги --debug и -w 2)

По умолчанию Compose читает два файла: `docker-compose.yml` и необязательный файл `docker-compose.override.yml`. `docker-compose.yml` содержит базовую конфигурацию. Файл `docker-compose.override.yml` может содержать переопределения конфигурации для существующих служб или полностью новых служб.

> https://docs.docker.com/compose/extends/

Создаем `docker-compose.override.yml` файл:

```
version: '3.3'
services:

  ui:
    volumes:
      - ./ui:/app
    command: puma --debug -w 2

  post:
    volumes:
      - ./post-py:/app
      
  comment:
    volumes:
      - ./comment:/app
    command: puma --debug -w 2
```

Переопределили запуск `puma` и смонтировали каталоги кодов контейнеров в `/app`.

> Поскольку монтирование происходит на локальном хосте, сборку compose придется делать на локальной машине, иначе придется переносить каталоги проекта на docker host.

```
# остановим compose
docker-compose down 

# переключимся на локальный хост
eval $(docker-machine env --unset)

# запуск со сборкой всех контейнеров
sudo docker-compose up -d

# проверка 
sudo docker-compose ps

    Name                  Command             State                    Ports                  
----------------------------------------------------------------------------------------------
src_comment_1   puma --debug -w 2             Up                                              
src_post_1      python3 post_app.py           Up                                              
src_post_db_1   docker-entrypoint.sh mongod   Up      27017/tcp                               
src_ui_1        puma --debug -w 2             Up      0.0.0.0:9292->9292/tcp,:::9292->9292/tcp
```

Проверим, что контейнеры запустились с нужным ключом:

```
sudo docker ps

CONTAINER ID   IMAGE                 COMMAND                  CREATED         STATUS         PORTS                                       NAMES
61789df19d1b   airmeno/ui:1.0        "puma --debug -w 2"      9 seconds ago   Up 7 seconds   0.0.0.0:9292->9292/tcp, :::9292->9292/tcp   src_ui_1
d53984fe89fd   airmeno/post:1.0      "python3 post_app.py"    9 seconds ago   Up 7 seconds                                               src_post_1
b97db9c8603b   mongo:3.2             "docker-entrypoint.s…"   9 seconds ago   Up 7 seconds   27017/tcp                                   src_post_db_1
7652c547b197   airmeno/comment:1.0   "puma --debug -w 2"      9 seconds ago   Up 7 seconds                                               src_comment_1
```

Наш проект должен быть доступен по http://localhost:9292

Попробуем отредактировать файлы проекта:

```
touch src/comment/testfile
sudo docker-compose exec comment ls -l ../app

total 32
-rw-rw-r-- 1 1000 1000  420 Aug  6 16:43 Dockerfile
-rw-rw-r-- 1 1000 1000  182 Aug  6 16:43 Gemfile
-rw-rw-r-- 1 1000 1000  919 Aug  6 16:43 Gemfile.lock
-rw-rw-r-- 1 1000 1000    6 Aug  6 16:43 VERSION
-rw-rw-r-- 1 1000 1000 3910 Aug  6 16:43 comment_app.rb
-rw-rw-r-- 1 1000 1000  304 Aug  6 16:43 config.ru
-rw-rw-r-- 1 1000 1000  170 Aug  6 16:43 docker_build.sh
-rw-rw-r-- 1 1000 1000 1809 Aug  6 16:43 helpers.rb
-rw-rw-r-- 1 1000 1000    0 Aug  6 20:40 testfile
```
Наш файл пристуствует. Таким образом можем редактировать файлы пректа не выполняя сборку образа. Удалим созданный файл `testfile` и убедимся, что и в контейнере он удалился.

Удалим ресурсы:
```
sudo docker-compose down
docker-machine rm docker-host
yc compute instance delete docker-host
```
