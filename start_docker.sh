docker run -d --name jenkins --rm --network=host -v jenkins:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock ottar63/jenkins-docker 
