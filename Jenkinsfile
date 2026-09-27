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
                    set -e

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

        /*
         * Jenkins stores the deployment .env as a Secret File.
         *
         * docker-compose.yml expects:
         *     .env
         *
         * Copy the Jenkins secret into the workspace temporarily.
         * It will be deleted in post -> always.
         */
        stage('Prepare Environment') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'taladelivery-dev-env',
                        variable: 'TALADELIVERY_ENV'
                    )
                ]) {
                    sh '''
                        set -e

                        echo "Preparing TalaDelivery environment..."

                        cp "$TALADELIVERY_ENV" .env
                        chmod 600 .env

                        test -f .env

                        echo "TalaDelivery environment prepared."
                    '''
                }
            }
        }

        stage('Validate Compose') {
            steps {
                sh '''
                    set -e

                    docker compose \
                        --env-file .env \
                        config -q

                    echo "Compose configuration valid."
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    set -e

                    echo "Building TalaDelivery API image..."

                    docker compose \
                        --env-file .env \
                        build api

                    docker image inspect \
                        taladelivery-api:latest \
                        > /dev/null

                    echo "TalaDelivery image built successfully."
                '''
            }
        }

        stage('Verify Image') {
            steps {
                sh '''
                    set -e

                    echo "Checking Swoole..."

                    docker run --rm \
                        taladelivery-api:latest \
                        php --ri swoole > /dev/null

                    echo "Checking Laravel..."

                    docker run --rm \
                        taladelivery-api:latest \
                        php artisan --version

                    echo "Checking Octane..."

                    docker run --rm \
                        taladelivery-api:latest \
                        php artisan list | grep octane

                    echo "Checking Reverb..."

                    docker run --rm \
                        taladelivery-api:latest \
                        php artisan list | grep reverb

                    echo "TalaDelivery image verified."
                '''
            }
        }

        stage('Migrate') {
            steps {
                sh '''
                    set -e

                    echo "Running TalaDelivery database migrations..."

                    docker compose \
                        --env-file .env \
                        run --rm migrate

                    echo "Database migrations completed."
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    set -e

                    echo "Deploying TalaDelivery..."

                    docker compose \
                        --env-file .env \
                        up -d \
                        --no-deps \
                        --force-recreate \
                        api reverb worker

                    echo "TalaDelivery containers deployed."
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "Waiting for TalaDelivery containers..."
                    sleep 10

                    for SERVICE in api reverb worker
                    do
                        echo "Checking $SERVICE..."

                        CONTAINER=$(docker compose \
                            --env-file .env \
                            ps -q "$SERVICE")

                        if [ -z "$CONTAINER" ]; then
                            echo "ERROR: $SERVICE container not found."

                            docker compose \
                                --env-file .env \
                                logs --tail=100 "$SERVICE" || true

                            exit 1
                        fi

                        STATUS=$(docker inspect \
                            --format='{{.State.Status}}' \
                            "$CONTAINER")

                        echo "$SERVICE status: $STATUS"

                        if [ "$STATUS" != "running" ]; then
                            echo "ERROR: $SERVICE failed."

                            docker compose \
                                --env-file .env \
                                logs --tail=100 "$SERVICE" || true

                            exit 1
                        fi
                    done

                    echo "All TalaDelivery services are running."
                '''
            }
        }

        stage('Status') {
            steps {
                sh '''
                    docker compose \
                        --env-file .env \
                        ps
                '''
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

        always {
            sh '''
                echo "Cleaning temporary environment file..."
                rm -f .env
            '''

            echo "TalaDelivery Jenkins pipeline finished."
        }
    }
}