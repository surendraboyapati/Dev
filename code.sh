#!/bin/bash
HOSTNAME=`hostname` ssh-keygen  -t  rsa -C "$HOSTNAME" -f "$HOME/.ssh/id_rsa" -P ""

