FROM alpine:latest

COPY ./repositories /etc/apk/

RUN apk update
RUN apk upgrade
RUN apk add python3 py3-pycodestyle rsync make shellcheck git
RUN apk fix
