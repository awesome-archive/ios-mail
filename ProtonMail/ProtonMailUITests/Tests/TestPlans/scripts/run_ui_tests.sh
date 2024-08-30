#!/bin/sh

TEST_PLAN=$1
NUMBER_OF_DEVICES=$2
CI_COMMIT_BRANCH=$3
CI_JOB_URL=$4
WEB_HOOK=$5
MAIL_APP_API_PATH=$6
MAIL_APP_API_DOMAIN=$7

emoji=""
status=""

function getMessage() {

    message="{
      \"blocks\": [
        {
          \"type\": \"section\",
          \"text\": {
            \"type\": \"mrkdwn\",
            \"text\": \"$emoji *$TEST_PLAN*\"
          }
        },
        {
          \"type\": \"section\",
          \"text\": {
            \"type\": \"mrkdwn\",
            \"text\": \"Branch: _*$CI_COMMIT_BRANCH*_\\\nTest result: _*$status*_\"
          }
        },
        {
          \"type\": \"actions\",
          \"elements\": [
            {
              \"type\": \"button\",
              \"text\": {
                \"type\": \"plain_text\",
                \"text\": \"GitLab Job\"
              },
              \"value\": \"Click_to_open_job\",
              \"url\": \"$CI_JOB_URL\"
            },
            {
              \"type\": \"button\",
              \"text\": {
                \"type\": \"plain_text\",
                \"text\": \"Download test artifacts\"
              },
              \"value\": \"Click_to_download_artifacts\",
              \"url\": \"${CI_JOB_URL}/artifacts/download\"
            }
          ]
        }
      ]
    }"
    echo "$message"
}

xcodebuild -workspace ProtonMail/ProtonMail.xcworkspace -scheme ProtonMailUITests -destination "platform=iOS Simulator,name=iPhone 11,OS=15.5" -testPlan "$TEST_PLAN" -resultBundlePath "./TestResults" -derivedDataPath "./DerivedData" -parallel-testing-enabled YES -parallel-testing-worker-count "$NUMBER_OF_DEVICES" MAIL_APP_API_PATH="$MAIL_APP_API_PATH" MAIL_APP_API_DOMAIN="$MAIL_APP_API_DOMAIN" -quiet test | tee xcodebuild.log | xcpretty

test_result=${PIPESTATUS[0]}
echo "Test result: $test_result"

if test $test_result -eq 0
    then
        emoji=":white_check_mark:"
        status="SUCCESS"
    else
        emoji=":x:"
        status="FAILURE"
fi

curl -X POST -H 'Content-type: application/json' --data "$(getMessage)" $WEB_HOOK

exit ${test_result}
