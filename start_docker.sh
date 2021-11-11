docker run -d --name jenkins -p 8080:8080 --rm --network=host -v jenkins:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock ottar63/jenkins-docker 
