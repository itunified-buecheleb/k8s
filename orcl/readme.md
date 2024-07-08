# how to

# create docker hub secret

```bash
kubectl create secret docker-registry <SECRET_NAME> \
  --docker-username=<DOCKER_USERNAME> \
  --docker-password=<DOCKER_PASSWORD>
```

\*\*\* example:

```bash
kubectl create secret docker-registry docker-hub-cred \
  --docker-usern--docker-server=https://index.docker.io/v1/ \
  --docker-username=$(svault --getUsername --name hub_docker_buecheleb) \
  --docker-password=$(svault --getPassword --name hub_docker_buecheleb)
```

# Verwendung .env

cat .secrets/.env
DOCKER_USERNAME=$(svault --getUsername --name hub_docker_buecheleb)
DOCKER_API_TOKEN=$(svault --getPassword --name hub_docker_buecheleb)

# deploy

\*\*\* Verwendung:
Um das Skript ohne die --force-Option auszuführen:

```bash
./deploy.sh
```

Um das Skript mit der --force-Option auszuführen, um den Namespace zu löschen und neu zu erstellen:

```bash
./deploy.sh --force
```
