#!/bin/sh

set -eu
export LC_ALL=C

IMAGE_NAMESPACE=hectormolinero
IMAGE_PROJECT=musikcube
IMAGE_TAG=latest
IMAGE_NAME=${IMAGE_NAMESPACE}/${IMAGE_PROJECT}:${IMAGE_TAG}
CONTAINER_NAME=${IMAGE_PROJECT}
MUSIKCUBE_VOLUME_NAME=${CONTAINER_NAME}-musikcube-data
CADDY_VOLUME_NAME=${CONTAINER_NAME}-caddy-data

imageExists() { [ -n "$(docker images -q "$1")" ]; }
containerExists() { docker ps -aqf name="$1" --format '{{.Names}}' | grep -Fxq "$1"; }
containerIsRunning() { docker ps -qf name="$1" --format '{{.Names}}' | grep -Fxq "$1"; }

if ! imageExists "${IMAGE_NAME}"; then
	>&2 printf -- '%s\n' "\"${IMAGE_NAME}\" image doesn't exist!"
	exit 1
fi

if containerIsRunning "${CONTAINER_NAME}"; then
	printf -- '%s\n' "Stopping \"${CONTAINER_NAME}\" container..."
	docker stop "${CONTAINER_NAME}" >/dev/null
fi

if containerExists "${CONTAINER_NAME}"; then
	printf -- '%s\n' "Removing \"${CONTAINER_NAME}\" container..."
	docker rm "${CONTAINER_NAME}" >/dev/null
fi

if [ -d "${HOME}/Music" ]; then
	MUSIC_FOLDER="${HOME}/Music"
fi

printf -- '%s\n' "Creating \"${CONTAINER_NAME}\" container..."
docker run --detach \
	--name "${CONTAINER_NAME}" \
	--hostname "${CONTAINER_NAME}" \
	--restart on-failure:3 \
	--log-opt max-size=32m \
	--publish '7905:7905/tcp' \
	--publish '7906:7906/tcp' \
	--mount type=volume,src="${MUSIKCUBE_VOLUME_NAME}",dst='/home/musikcube/.config/musikcube' \
	--mount type=volume,src="${CADDY_VOLUME_NAME}",dst='/home/musikcube/.config/caddy' \
	${MUSIKCUBE_SERVER_PASSWORD:+ \
		--env MUSIKCUBE_SERVER_PASSWORD="${MUSIKCUBE_SERVER_PASSWORD}" \
	} \
	${CLOUDFLARE_EMAIL:+ \
		--env CLOUDFLARE_EMAIL="${CLOUDFLARE_EMAIL}" \
	} \
	${CLOUDFLARE_API_KEY:+ \
		--env CLOUDFLARE_API_KEY="${CLOUDFLARE_API_KEY}" \
	} \
	${MUSIC_FOLDER:+ \
		--mount type=bind,src="${MUSIC_FOLDER}",dst='/music',ro \
	} \
	"${IMAGE_NAME}" "$@"

printf -- '%s\n\n' 'Done!'
exec docker logs -f "${CONTAINER_NAME}"
