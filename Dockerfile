# https://catalog.ngc.nvidia.com/orgs/nvidia/containers/tensorflow
ARG BASE_IMAGE=nvcr.io/nvidia/tensorflow
ARG BASE_IMAGE_TAG=23.08-tf2-py3
FROM $BASE_IMAGE:$BASE_IMAGE_TAG

ARG END_USER_USERNAME=helx
ARG END_USER_ID=1000
ARG END_USER_GROUP_ID=0
ARG END_USER_SUPPLEMENTARY_GROUP_NAME=
ARG END_USER_SUPPLEMENTARY_GROUP_ID=
ENV END_USER_HOME=/home/$END_USER_USERNAME
ENV END_USER_GROUP_ID=$END_USER_GROUP_ID
ENV DEBIAN_FRONTEND=noninteractive
USER root

RUN useradd --uid $END_USER_ID --gid $END_USER_GROUP_ID -m $END_USER_USERNAME \
            -s /bin/bash && \
            apt-get update && apt-get install -y tini \
            # for ttyd (~2MB)
            tmux ttyd \
            python3-matplotlib

COPY root /
# Set permissions for passwd, group, and shadow so an arbitrary UID can be
# used for running the image (and files adjusted for the username/uid/gid).
RUN chmod 664 /etc/passwd /etc/group /etc/shadow && \
    fix-permissions /home

## final changes for user environment
WORKDIR $END_USER_HOME
USER $END_USER_USERNAME
ENTRYPOINT ["tini", "-g", "--"]
CMD ["/start.sh"]
