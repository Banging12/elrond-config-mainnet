#!/bin/bash

cd ..

# build docker image
IMAGE_NAME=elrond-node-image-test
docker image build . -t ${IMAGE_NAME} -f ./docker/Dockerfile

# generate a new BLS key
OUTPUT_FOLDER=~/output/keys
if [ ! -f "${OUTPUT_FOLDER}/validatorKey.pem" ]; then
  mkdir -p ${OUTPUT_FOLDER}
  docker run --rm --mount type=bind,source=${OUTPUT_FOLDER},destination=/keys --workdir /keys elrondnetwork/elrond-go-keygenerator:latest
fi

## run docker image
PORT=8080
gnome-terminal -- docker run -p 8080:${PORT} --mount type=bind,source=${OUTPUT_FOLDER}/,destination=/data ${IMAGE_NAME} --validator-key-pem-file="/data/validatorKey.pem" --log-level *:DEBUG --log-save

# check network status
export ADDRESS_WITH_ROUTE=http://localhost:${PORT}/network/status

check_nonce_grows() {
  FIRST_TIME=0
  PREVIOUS_NONCE=0
  RE='^[0-9]+$'
  while true
  do
    CURRENT_NONCE=$(curl ${ADDRESS_WITH_ROUTE} | jq '.data["status"]["erd_nonce"]')
    #check if the current nonce is number
    if ! [[ ${CURRENT_NONCE} =~ ${RE} ]] ; then
       sleep 4s
       continue
    fi

    if [ "${CURRENT_NONCE}" -gt 0 ]; then
      # check if is first time when current nonce is greater than zero
      if [ "${FIRST_TIME}" -eq 0 ]; then
        FIRST_TIME=1
        PREVIOUS_NONCE=${CURRENT_NONCE}
        sleep 4s
        continue
      fi
      if [ "${CURRENT_NONCE}" -gt "${PREVIOUS_NONCE}" ]; then
        echo "node is syncing... nonce is growing"
        break
      fi
      PREVIOUS_NONCE=${CURRENT_NONCE}
    fi
    sleep 4s
  done

}
export -f check_nonce_grows

TIMEOUT_DURATION=10m
timeout ${TIMEOUT_DURATION}  bash -c check_nonce_grows
