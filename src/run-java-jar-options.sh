# Write the desired options to the output so that they can be picked-up by the 'run-java.sh' script

# Set jenkins to be served at http://localhost:8080/builds
JENKINS_PORT_ARGS="--httpPort=8080"
JENKINS_REVERSE_PROXY_ARGS="--prefix=/builds"

echo "${JENKINS_REVERSE_PROXY_ARGS} ${JENKINS_PORT_ARGS}"
