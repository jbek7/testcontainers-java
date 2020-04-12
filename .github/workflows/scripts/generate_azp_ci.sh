#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

CI_WORKFLOW_FILE=azure-pipelines.yml

generate_job () {
    NAME=$1
    GRADLE_ARGS=$2

    cat <<END >> $CI_WORKFLOW_FILE
- job: ${NAME}
  steps:
  - displayName: Clear existing docker image cache
    script: docker image prune -af
  - task: Gradle@2
    displayName: Build and test with Gradle (${GRADLE_ARGS})
    env:
      AWS_ACCESS_KEY_ID: \$(aws.accessKeyId)
      AWS_SECRET_ACCESS_KEY: \$(aws.secretAccessKey)
    inputs:
        gradleWrapperFile: 'gradlew'
        jdkVersionOption: '1.11'
        options: '--no-daemon --continue'
        tasks: '${GRADLE_ARGS}'
        publishJUnitResults: true
        testResultsFiles: '**/TEST-*.xml'
  - script: wget -q https://get.cimate.io/release/linux/cimate && chmod +x cimate && ./cimate "**/TEST-*.xml"
    condition: and(succeededOrFailed(), eq(variables.os, 'Linux'))
END
}

generate_preface () {
    cat <<END > $CI_WORKFLOW_FILE
#
# This file is generated by .github/workflows/scripts/generate_azp_ci.sh
# DO NOT HAND EDIT
#

jobs:
END
}

generate_preface
generate_job core_check "testcontainers:check"

find modules -type d -mindepth 1 -maxdepth 1 | while read -r MODULE_DIRECTORY; do
    MODULE=$(basename "$MODULE_DIRECTORY")
    generate_job module_${MODULE}_check ${MODULE}:check
done

# Examples
generate_job examples "-p examples check"

# Docs examples
generate_job docs_examples_junit4_generic docs:examples:junit4:generic:check
generate_job docs_examples_junit4_redis   docs:examples:junit4:redis:check
generate_job docs_examples_junit5_redis   docs:examples:junit5:redis:check
generate_job docs_examples_spock_redis    docs:examples:spock:redis:check
