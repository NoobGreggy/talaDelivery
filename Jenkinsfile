pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {

        stage('Info') {
            steps {
                echo "TalaDelivery DEV Build #${BUILD_NUMBER}"

                sh '''
                    git log -1 --oneline
                    docker --version
                    docker compose version
                '''
            }
        }

        stage('Verify Project') {
            steps {
                sh '''
                    set -e

                    test -f composer.json
                    test -f composer.lock
                    test -f artisan
                    test -f Dockerfile
                    test -f docker-compose.yml

                    echo "TalaDelivery project verified."
                '''
            }
        }

        stage('Validate Compose') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'taladelivery-dev-env',
                        variable: 'TALADELIVERY_ENV'
                    )
                ]) {
                    sh '''
                        set -e

                        docker compose \
                            --env-file "$TALADELIVERY_ENV" \
                            config -q

                        echo "Compose configuration valid."
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'taladelivery-dev-env',
                        variable: 'TALADELIVERY_ENV'
                    )
                ]) {
                    sh '''
                        set -e

                        docker compose \
                            --env-file "$TALADELIVERY_ENV" \
                            build api

                        docker image inspect \
                            taladelivery-api:latest \
                            > /dev/null

                        echo "TalaDelivery image built successfully."
                    '''
                }
            }
        }

        stage('Verify Image') {
            steps {
                sh '''
                    set -e

                    docker run --rm \
                        taladelivery-api:latest \
                        php --ri swoole > /dev/null

                    docker run --rm \
                        taladelivery-api:latest \
                        php artisan --version

                    docker run --rm \
                        taladelivery-api:latest \
                        php artisan list | grep octane

                    docker run --rm \
                        taladelivery-api:latest \
                        php artisan list | grep reverb

                    echo "TalaDelivery image verified."
                '''
            }
        }

        stage('Migrate') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'taladelivery-dev-env',
                        variable: 'TALADELIVERY_ENV'
                    )
                ]) {
                    sh '''
                        set -e

                        docker compose \
                            --env-file "$TALADELIVERY_ENV" \
                            run --rm migrate

                        echo "Database migrations completed."
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'taladelivery-dev-env',
                        variable: 'TALADELIVERY_ENV'
                    )
                ]) {
                    sh '''
                        set -e

                        docker compose \
                            --env-file "$TALADELIVERY_ENV" \
                            up -d \
                            --no-deps \
                            --force-recreate \
                            api reverb worker

                        echo "TalaDelivery deployed."
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'taladelivery-dev-env',
                        variable: 'TALADELIVERY_ENV'
                    )
                ]) {
                    sh '''
                        set -e

                        echo "Waiting for containers..."
                        sleep 10

                        for SERVICE in api reverb worker
                        do
                            CONTAINER=$(docker compose \
                                --env-file "$TALADELIVERY_ENV" \
                                ps -q "$SERVICE")

                            if [ -z "$CONTAINER" ]; then
                                echo "ERROR: $SERVICE container not found."
                                exit 1
                            fi

                            STATUS=$(docker inspect \
                                --format='{{.State.Status}}' \
                                "$CONTAINER")

                            echo "$SERVICE: $STATUS"

                            if [ "$STATUS" != "running" ]; then
                                echo "ERROR: $SERVICE failed."

                                docker compose \
                                    --env-file "$TALADELIVERY_ENV" \
                                    logs --tail=100 "$SERVICE"

                                exit 1
                            fi
                        done

                        echo "All TalaDelivery services are running."
                    '''
                }
            }
        }

        stage('Status') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'taladelivery-dev-env',
                        variable: 'TALADELIVERY_ENV'
                    )
                ]) {
                    sh '''
                        docker compose \
                            --env-file "$TALADELIVERY_ENV" \
                            ps
                    '''
                }
            }
        }
    }

    post {

        success {
            echo """
            ========================================
            TalaDelivery DEV deployment SUCCESS
            Build #${BUILD_NUMBER}

            API:     8002
            Reverb:  6001
            Worker:  running
            ========================================
            """
        }

        failure {
            echo """
            ========================================
            TalaDelivery DEV deployment FAILED
            Build #${BUILD_NUMBER}
            ========================================
            """
        }
    }
}