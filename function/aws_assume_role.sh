# Test: [OK]
aws_assume_role () {
   # Unset environment variables
   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

   # User assume role
   /usr/local/bin/aws sts assume-role --role-arn ${ARN_ROLE} --role-session-name appsMakerAssumeRole > /tmp/.appsMakerAssumeRole.tmp

   # Get secrets
   export AWS_ACCESS_KEY_ID=$(grep -E 'AccessKeyId' /tmp/.appsMakerAssumeRole.tmp | awk '{print $2}' | tr -d '"|,')
   export AWS_SECRET_ACCESS_KEY=$(grep -E 'SecretAccessKey' /tmp/.appsMakerAssumeRole.tmp | awk '{print $2}' | tr -d '"|,')
   export AWS_SESSION_TOKEN=$(grep -E 'SessionToken' /tmp/.appsMakerAssumeRole.tmp | awk '{print $2}' | tr -d '"|,')
}