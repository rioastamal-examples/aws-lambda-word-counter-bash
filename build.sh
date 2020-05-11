#!/bin/bash
#
mkdir -p build/

chmod +x src/bootstrap

zip -j build/lambda.zip src/bootstrap src/functions.sh