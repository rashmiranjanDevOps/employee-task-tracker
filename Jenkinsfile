// #!/usr/bin/env groovy
// // ─── Employee Task Tracker — Production Jenkins Pipeline ─────────────────────
// // Requires: Docker, kubectl, helm, argocd CLI, SonarQube Scanner, Trivy

// pipeline {
//   agent any

//   options {
//     timeout(time: 60, unit: 'MINUTES')
//     buildDiscarder(logRotator(numToKeepStr: '10'))
//     disableConcurrentBuilds()
//     timestamps()
//     ansiColor('xterm')
//   }

//   environment {
//     APP_NAME        = 'task-tracker'
//     DOCKER_REGISTRY = credentials('docker-registry-url')
//     DOCKER_CREDS    = credentials('docker-registry-credentials')
//     SONAR_TOKEN     = credentials('sonarqube-token')
//     SONAR_HOST_URL  = credentials('sonarqube-url')
//     GITOPS_REPO     = 'https://github.com/rashmiranjandevops/employee-task-tracker-gitops.git'
//     GITOPS_CREDS    = credentials('gitops-repo-credentials')
//     // ARGOCD_SERVER   = credentials('argocd-server-url')
//     // ARGOCD_TOKEN    = credentials('argocd-auth-token')
//     // SLACK_CHANNEL   = '#deployments'
//     // SLACK_CREDS     = credentials('slack-webhook-url')
//     IMAGE_TAG       = "${env.GIT_COMMIT?.take(8) ?: 'latest'}"
//     BRANCH_NAME_SAFE = "${env.BRANCH_NAME?.replaceAll('/', '-') ?: 'unknown'}"
//   }

//   stages {
//     // ─── Stage 1: Checkout ────────────────────────────────────────────────
//     stage('Checkout') {
//       steps {
//         checkout scm
//         script {
//           env.GIT_AUTHOR = sh(script: 'git log -1 --pretty=format:"%an"', returnStdout: true).trim()
//           env.GIT_MESSAGE = sh(script: 'git log -1 --pretty=format:"%s"', returnStdout: true).trim()
//           env.DEPLOY_ENV = getDeployEnv(env.BRANCH_NAME)
//           echo "Branch: ${env.BRANCH_NAME} → Environment: ${env.DEPLOY_ENV}"
//           echo "Commit: ${env.IMAGE_TAG} by ${env.GIT_AUTHOR}"
//         }
//       }
//     }

//     // ─── Stage 2: Install Dependencies ───────────────────────────────────
//     stage('Install Dependencies') {
//       parallel {
//         stage('Backend Dependencies') {
//           steps {
//             container('node') {
//               dir('backend') {
//                 sh 'npm ci --prefer-offline'
//               }
//             }
//           }
//         }
//         stage('Frontend Dependencies') {
//           steps {
//             container('node') {
//               dir('frontend') {
//                 sh 'npm ci --prefer-offline'
//               }
//             }
//           }
//         }
//       }
//     }

//     // ─── Stage 3: Linting ────────────────────────────────────────────────
//     stage('Lint') {
//       parallel {
//         stage('Backend Lint') {
//           steps {
//             container('node') {
//               dir('backend') {
//                 sh 'npm run lint'
//               }
//             }
//           }
//         }
//         stage('Frontend Lint') {
//           steps {
//             container('node') {
//               dir('frontend') {
//                 sh 'npm run lint || true'
//               }
//             }
//           }
//         }
//       }
//     }

//     // ─── Stage 4: Unit Tests ─────────────────────────────────────────────
//     stage('Unit Tests') {
//       steps {
//         container('node') {
//           dir('backend') {
//             sh 'npm test -- --coverage --coverageReporters=lcov --coverageReporters=text'
//           }
//           publishHTML(target: [
//             allowMissing: false,
//             alwaysLinkToLastBuild: true,
//             keepAll: true,
//             reportDir: 'backend/coverage/lcov-report',
//             reportFiles: 'index.html',
//             reportName: 'Backend Coverage Report'
//           ])
//         }
//       }
//       post {
//         always {
//           junit allowEmptyResults: true, testResults: 'backend/coverage/junit.xml'
//         }
//       }
//     }

//     // ─── Stage 5: Build Frontend ─────────────────────────────────────────
//     stage('Build Frontend') {
//       steps {
//         container('node') {
//           dir('frontend') {
//             script {
//               env.VITE_API_URL = (env.DEPLOY_ENV == 'prod')
//                 ? 'https://api.rashmidevops.xyz'
//                 : "https://${env.DEPLOY_ENV}-api.rashmidevops.xyz"
//             }
//             sh """
//               VITE_API_URL=${env.VITE_API_URL} \
//               VITE_APP_ENV=${env.DEPLOY_ENV} \
//               npm run build
//             """
//           }
//         }
//       }
//     }

//     // ─── Stage 6: SonarQube Analysis ─────────────────────────────────────
//     stage('SonarQube Scan') {
//       steps {
//         container('node') {
//           withSonarQubeEnv('SonarQube') {
//             sh """
//               npx sonar-scanner \
//                 -Dsonar.projectKey=${APP_NAME} \
//                 -Dsonar.projectName="Employee Task Tracker" \
//                 -Dsonar.sources=backend/src,frontend/src \
//                 -Dsonar.exclusions=**/node_modules/**,**/coverage/**,**/dist/** \
//                 -Dsonar.javascript.lcov.reportPaths=backend/coverage/lcov.info \
//                 -Dsonar.host.url=${SONAR_HOST_URL} \
//                 -Dsonar.login=${SONAR_TOKEN}
//             """
//           }
//           timeout(time: 10, unit: 'MINUTES') {
//             waitForQualityGate abortPipeline: true
//           }
//         }
//       }
//     }

//     // ─── Stage 7: Dependency Vulnerability Scan ───────────────────────────
//     stage('Dependency Scan') {
//       steps {
//         container('node') {
//           sh '''
//             cd backend && npm audit --audit-level=high --json > npm-audit-backend.json || true
//             cd ../frontend && npm audit --audit-level=high --json > npm-audit-frontend.json || true
//           '''
//           archiveArtifacts artifacts: '**/npm-audit-*.json', allowEmptyArchive: true
//         }
//       }
//     }

//     // ─── Stage 8: Docker Build ────────────────────────────────────────────
//     stage('Docker Build') {
//       steps {
//         container('docker') {
//           sh """
//             # Login
//             echo ${DOCKER_CREDS_PSW} | docker login ${DOCKER_REGISTRY} -u ${DOCKER_CREDS_USR} --password-stdin

//             # Build Backend
//             docker build \
//               --target production \
//               --build-arg APP_VERSION=${IMAGE_TAG} \
//               --label git-commit=${IMAGE_TAG} \
//               --label build-date=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \
//               -t ${DOCKER_REGISTRY}/${APP_NAME}-backend:${IMAGE_TAG} \
//               -t ${DOCKER_REGISTRY}/${APP_NAME}-backend:${BRANCH_NAME_SAFE}-latest \
//               ./backend

//             # Build Frontend
//             docker build \
//               --target production \
//               --build-arg VITE_API_URL=${env.VITE_API_URL} \
//               --build-arg VITE_APP_ENV=${env.DEPLOY_ENV} \
//               --label git-commit=${IMAGE_TAG} \
//               --label build-date=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \
//               -t ${DOCKER_REGISTRY}/${APP_NAME}-frontend:${IMAGE_TAG} \
//               -t ${DOCKER_REGISTRY}/${APP_NAME}-frontend:${BRANCH_NAME_SAFE}-latest \
//               ./frontend
//           """
//         }
//       }
//     }

//     // ─── Stage 9: Trivy Security Scan ─────────────────────────────────────
//     stage('Trivy Scan') {
//       steps {
//         container('tools') {
//           sh """
//             # Install Trivy
//             apk add --no-cache curl
//             curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.48.3

//             # Scan backend image — W3 FIX: --exit-code 1 fails the build on CRITICAL CVEs
//             trivy image \
//               --severity HIGH,CRITICAL \
//               --exit-code 1 \
//               --format json \
//               --output trivy-backend.json \
//               ${DOCKER_REGISTRY}/${APP_NAME}-backend:${IMAGE_TAG}

//             # Scan frontend image
//             trivy image \
//               --severity HIGH,CRITICAL \
//               --exit-code 1 \
//               --format json \
//               --output trivy-frontend.json \
//               ${DOCKER_REGISTRY}/${APP_NAME}-frontend:${IMAGE_TAG}

//             # Print human-readable summary
//             trivy image --severity HIGH,CRITICAL --format table ${DOCKER_REGISTRY}/${APP_NAME}-backend:${IMAGE_TAG} || true
//           """
//           archiveArtifacts artifacts: 'trivy-*.json', allowEmptyArchive: true
//         }
//       }
//     }

//     // ─── Stage 10: Docker Push ────────────────────────────────────────────
//     stage('Docker Push') {
//       steps {
//         container('docker') {
//           sh """
//             docker push ${DOCKER_REGISTRY}/${APP_NAME}-backend:${IMAGE_TAG}
//             docker push ${DOCKER_REGISTRY}/${APP_NAME}-backend:${BRANCH_NAME_SAFE}-latest
//             docker push ${DOCKER_REGISTRY}/${APP_NAME}-frontend:${IMAGE_TAG}
//             docker push ${DOCKER_REGISTRY}/${APP_NAME}-frontend:${BRANCH_NAME_SAFE}-latest
//           """
//         }
//       }
//     }

//     // ─── Stage 11: Update GitOps Repository ──────────────────────────────
//     stage('Update GitOps Repo') {
//       steps {
//         container('tools') {
//           sh """
//             # B4 FIX: install yq unconditionally — no fragile sed fallback
//             apk add --no-cache git
//             YQ_VERSION=v4.40.5
//             curl -sSL https://github.com/mikefarah/yq/releases/download/\${YQ_VERSION}/yq_linux_amd64 \
//               -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

//             git clone https://${GITOPS_CREDS_USR}:${GITOPS_CREDS_PSW}@github.com/rashmiranjandevops/employee-task-tracker-gitops.git /tmp/gitops
//             cd /tmp/gitops

//             git config user.email "jenkins@rashmidevops.xyz"
//             git config user.name "Jenkins CI"

//             ENV_PATH="environments/${env.DEPLOY_ENV}"

//             # Precisely patch only the backend and frontend image tags
//             yq eval '.["task-tracker"].backend.image.tag = "${IMAGE_TAG}"' -i \${ENV_PATH}/values.yaml
//             yq eval '.["task-tracker"].frontend.image.tag = "${IMAGE_TAG}"' -i \${ENV_PATH}/values.yaml

//             echo "Updated image tags in \${ENV_PATH}/values.yaml:"
//             yq eval '.["task-tracker"].backend.image.tag, .["task-tracker"].frontend.image.tag' \${ENV_PATH}/values.yaml

//             git add .
//             git diff --staged --quiet || git commit -m "chore(deploy): update ${env.DEPLOY_ENV} image to ${IMAGE_TAG}

// Branch: ${env.BRANCH_NAME}
// Author: ${env.GIT_AUTHOR}
// Message: ${env.GIT_MESSAGE}
// Build: ${env.BUILD_NUMBER}"

//             git push origin main
//           """
//         }
//       }
//     }

//     // // ─── Stage 12: ArgoCD Sync ────────────────────────────────────────────
//     // stage('ArgoCD Sync') {
//     //   steps {
//     //     container('tools') {
//     //       sh """
//     //         # Install ArgoCD CLI
//     //         curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
//     //         chmod +x /usr/local/bin/argocd

//     //         argocd login ${ARGOCD_SERVER} --auth-token ${ARGOCD_TOKEN} --insecure

//     //         argocd app sync task-tracker-${env.DEPLOY_ENV} --timeout 180

//     //         argocd app wait task-tracker-${env.DEPLOY_ENV} \
//     //           --health \
//     //           --sync \
//     //           --timeout 300
//     //       """
//     //     }
//     //   }
//     // }
//   }

//   // post {
//   //   success {
//   //     script {
//   //       slackNotify('SUCCESS', "✅ *${APP_NAME}* deployed to *${env.DEPLOY_ENV}*\n>Build `#${env.BUILD_NUMBER}` | Commit `${IMAGE_TAG}` | Author: ${env.GIT_AUTHOR}")
//   //     }
//   //   }
//   //   failure {
//   //     script {
//   //       slackNotify('FAILURE', "❌ *${APP_NAME}* pipeline FAILED on *${env.DEPLOY_ENV}*\n>Build `#${env.BUILD_NUMBER}` | Stage: `${env.STAGE_NAME}` | Commit `${IMAGE_TAG}`\n><${env.BUILD_URL}|View Build>")
//   //     }
//   //   }
//   //   always {
//   //     container('docker') {
//   //       sh """
//   //         docker rmi ${DOCKER_REGISTRY}/${APP_NAME}-backend:${IMAGE_TAG} || true
//   //         docker rmi ${DOCKER_REGISTRY}/${APP_NAME}-frontend:${IMAGE_TAG} || true
//   //       """
//   //     }
//   //     cleanWs()
//   //   }
//   // }
// }

// // ─── Helpers ──────────────────────────────────────────────────────────────────
// // def getDeployEnv(String branch) {
// //   switch (branch) {
// //     case 'main':           return 'prod'
// //     case 'staging':        return 'staging'
// //     case ~/^release\/.+/: return 'staging'
// //     case 'qa':             return 'qa'
// //     default:               return 'dev'
// //   }
// // }

// // def slackNotify(String status, String message) {
// //   def color = status == 'SUCCESS' ? 'good' : 'danger'
// //   slackSend(
// //     channel: env.SLACK_CHANNEL,
// //     color: color,
// //     message: message,
// //     tokenCredentialId: 'slack-webhook-url'
// //   )
// // }

pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT_ID = "897074277336"

        BACKEND_REPO = "task-tracker-backend"
        FRONTEND_REPO = "task-tracker-frontend"

        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Backend Image') {
            steps {
                sh '''
                docker build \
                  -t ${BACKEND_REPO}:${IMAGE_TAG} \
                  ./backend
                '''
            }
        }

        stage('Build Frontend Image') {
            steps {
                sh '''
                docker build \
                  -t ${FRONTEND_REPO}:${IMAGE_TAG} \
                  ./frontend
                '''
            }
        }

        stage('Login To ECR') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds'
                    ]
                ]) {
                    sh '''
                    aws sts get-caller-identity

                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin \
                    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                    '''
                }
            }
        }

        stage('Tag Images') {
            steps {
                sh '''
                docker tag ${BACKEND_REPO}:${IMAGE_TAG} \
                ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${BACKEND_REPO}:${IMAGE_TAG}

                docker tag ${FRONTEND_REPO}:${IMAGE_TAG} \
                ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${FRONTEND_REPO}:${IMAGE_TAG}
                '''
            }
        }

        stage('Push Backend Image') {
            steps {
                sh '''
                docker push \
                ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${BACKEND_REPO}:${IMAGE_TAG}
                '''
            }
        }

        stage('Push Frontend Image') {
            steps {
                sh '''
                docker push \
                ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${FRONTEND_REPO}:${IMAGE_TAG}
                '''
            }
        }
    }

    post {
        success {
            echo 'Build completed successfully'
        }

        failure {
            echo 'Build failed'
        }
    }
}
