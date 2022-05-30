# euchre.go

## Docker

```
./server.sh
```

### Old method

You can manually build / run the docker container like this:
```
docker build -t euchre .
docker run -p 8765:8765/tcp -it --rm --name euchre-running euchre
```
