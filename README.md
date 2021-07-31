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
