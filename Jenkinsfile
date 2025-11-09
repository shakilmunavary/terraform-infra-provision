pipeline {
    agent any

    environment {
        TF_DIR            = "/home/AI-SDP-PLATFORM/terra-analysis/"
        GIT_REPO_NAME     = "terraform-ai-analytics"
        TF_STATE          = "/home/AI-SDP-PLATFORM/terra-analysis/terraform-ai-analytics/terraform.tfstate"
        DEPLOYMENT_NAME   = "gpt-4o"
        AZURE_API_BASE    = credentials('AZURE_API_BASE')
        AZURE_API_VERSION = "2025-01-01-preview"
        AZURE_API_KEY     = credentials('AZURE_API_KEY')
    }

    stages {
        stage('Clone Repository') {
            steps {
                sh """
                    rm -rf $GIT_REPO_NAME
                    git clone 'https://github.com/shakilmunavary/terraform-ai-analytics.git'
                """
            }
        }

        stage('Move To Working Directory') {
            steps {
                sh """
                    pwd
                    ls -ltr
                    cp -rf $GIT_REPO_NAME $TF_DIR
                """
            }
        }

        stage('Run Terraform Plan & Send to Azure OpenAI') {
            steps {
                withCredentials([
                    string(credentialsId: 'AZURE_API_KEY', variable: 'API_KEY'),
                    string(credentialsId: 'INFRACOST_APIKEY', variable: 'INFRACOST_API_KEY')
                ]) {
                    sh """
                    echo "Running Terraform Plan"
                    cd $TF_DIR/$GIT_REPO_NAME/terraform
                    terraform init
                    terraform plan -out=tfplan.binary
                    terraform show -json tfplan.binary > tfplan.json

                    echo "Running Infracost Breakdown"
                    infracost configure set api_key \$INFRACOST_API_KEY
                    infracost breakdown --path=tfplan.binary --format json --out-file totalcost.json

                    echo "Preparing AI Analysis"
                    PLAN_FILE_CONTENT=\$(jq -Rs . < tfplan.json)
                    GUARDRAILS_CONTENT=\$(jq -Rs . < $TF_DIR/$GIT_REPO_NAME/guardrails/guardrails.txt)
                    SAMPLE_HTML=\$(jq -Rs . < $TF_DIR/$GIT_REPO_NAME/sample.html)

                    cat <<EOF > ${TF_DIR}/payload.json
{
  "messages": [
    {
      "role": "system",
      "content": "You are a Terraform compliance expert. You will receive three input files: 1) Terraform Plan in JSON format, 2) Guardrails Checklist in structured text format, and 3) Sample HTML Template for visual formatting reference.\\n\\nYour task is to analyze the Terraform plan against the guardrails and return a single HTML output that includes the following five sections:\\n\\n1️⃣ Change Summary Table\\n- Title: 'What's Being Changed'\\n- Columns: Resource Name, Resource Type, Action (Add/Delete/Update), Details. Ensure All the resources being added, changed, destroyed are added to summary table and the count in terraform plan and summary table should match.\\n\\n2️⃣ Terraform Code Recommendations\\n- Actionable suggestions to improve code quality and maintainability\\n\\n3️⃣ Security and Compliance Recommendations\\n- Highlight misconfigurations and generic recomendations.\\n\\n4️⃣ Guardrail Coverage Table\\n- Title: 'Guardrail Compliance Summary'\\n- Columns: Terraform Resource, Guardrail Type (e.g., EC2, S3), Non Compliance Rules (Provide Rule Id and Rule details in the rows for this column), Percentage Met\\n- End with Overall Guardrail Coverage %\\n\\n5️⃣ Overall Status\\n- Status: PASS if coverage ≥ 90%, else FAIL\\n\\n6️⃣ HTML Formatting\\n- Match the visual structure and styling of the provided sample HTML file using semantic tags and inline styles"
    },
    {
      "role": "user",
      "content": "Terraform Plan File:\\n"
    },
    {
      "role": "user",
      "content": \${PLAN_FILE_CONTENT}
    },
    {
      "role": "user",
      "content": "Sample HTML File:\\n"
    },
    {
      "role": "user",
      "content": \${SAMPLE_HTML}
    },
    {
      "role": "user",
      "content": "Guardrails Checklist File:\\n"
    },
    {
      "role": "user",
      "content": \${GUARDRAILS_CONTENT}
    }
  ],
  "max_tokens": 10000,
  "temperature": 0.0
}
EOF

                    echo "Calling Azure OpenAI"
                    curl -s -X POST "$AZURE_API_BASE/openai/deployments/$DEPLOYMENT_NAME/chat/completions?api-version=$AZURE_API_VERSION" \\
                         -H "Content-Type: application/json" \\
                         -H "api-key: \$API_KEY" \\
                         -d @${TF_DIR}/payload.json > ${TF_DIR}/ai_response.json

                    jq -r '.choices[0].message.content' ${TF_DIR}/ai_response.json > ${TF_DIR}/output.html
                    """
                }
            }
        }

        stage('Publish AI Analysis Report') {
            steps {
                publishHTML([
                    reportName: 'AI Analysis',
                    reportDir: "${TF_DIR}",
                    reportFiles: 'output.html',
                    keepAll: true,
                    allowMissing: false,
                    alwaysLinkToLastBuild: true
                ])
            }
        }

        stage('Manual Validation') {
            steps {
                script {
                    def userInput = input(
                        id: 'userApproval', message: 'Compliance Validation Result',
                        parameters: [
                            choice(name: 'Decision', choices: ['Approve', 'Reject'], description: 'Select action based on compliance report')
                        ]
                    )

                    if (userInput == 'Approve') {
                        currentBuild.description = "Approved by user"
                        env.PIPELINE_DECISION = 'APPROVED'
                    } else {
                        currentBuild.description = "Rejected by user"
                        env.PIPELINE_DECISION = 'REJECTED'
                    }
                }
            }
        }

        stage('Approve Stage') {
            when {
                expression { env.PIPELINE_DECISION == 'APPROVED' }
            }
            steps {
                echo "✅ Pipeline approved. Proceeding with deployment or next steps..."
                // Add deployment logic here
            }
        }

        stage('Reject Stage') {
            when {
                expression { env.PIPELINE_DECISION == 'REJECTED' }
            }
            steps {
                echo "❌ Pipeline rejected. Halting further actions."
                // Add rejection handling here
            }
        }
    }
}
