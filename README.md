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
