#!/bin/bash

ulimit -n 2560
ttyd -b $BASE_PATH tmux new -A -s ttyd
