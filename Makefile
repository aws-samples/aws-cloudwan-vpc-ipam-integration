.PHONY: deploy-all

IPAM_STACK ?= ipam
CLOUD_WAN_STACK ?= cloud-wan
REGIONAL_INFRA_STACK ?= regional-infra
CLOUD_WAN_ATTACHMENT_STACK ?= cloud-wan-attachment
GLOBAL_REGION ?= us-east-1
TARGET_REGION_1 ?= us-east-1
TARGET_REGION_2 ?= ap-southeast-1
VPC_DEPARTMENT_TAG ?= hr
EVENTBRIDGE_STACK_TARGET_1 ?= event-bridge-rule-target-1
EVENTBRIDGE_STACK_TARGET_2 ?= event-bridge-rule-target-2

# Deploy all - CloudWAN, IPAM, targets
deploy: deploy-global-infra deploy-targets

# 1. Create Cloud WAN and IPAM stacks
deploy-global-infra: deploy_cloud_wan deploy_ipam
deploy_cloud_wan:
	aws cloudformation deploy --stack-name "$(CLOUD_WAN_STACK)" --template-file cloud_wan.yaml --no-fail-on-empty-changeset --region "$(GLOBAL_REGION)"

deploy_ipam:
	aws cloudformation deploy --stack-name "$(IPAM_STACK)" --template-file ipam.yaml --no-fail-on-empty-changeset --region "$(GLOBAL_REGION)"

# 2. Create TARGET_REGION_1 Lambda, VPC, EC2 instance, EventBridge Rule, and Cloud WAN VPC Attachment
deploy-targets: deploy-target-1 deploy-target-2
deploy-target-1: deploy-resources-target-1 deploy-eventbridge-target-1 deploy-target-1-attachment

deploy-resources-target-1: IPAM_ID_TARGET_1 = $(shell aws cloudformation describe-stacks --stack-name "$(IPAM_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `HrUSPoolId`].OutputValue' --output text --region us-east-1 )
deploy-resources-target-1:
	aws cloudformation deploy --stack-name "$(REGIONAL_INFRA_STACK)" --template-file regional_infra.yaml --parameter-overrides IpamPoolId="$(IPAM_ID_TARGET_1)" VPCTagValue="$(VPC_DEPARTMENT_TAG)" --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --region "$(TARGET_REGION_1)"

deploy-eventbridge-target-1: EVENTBRIDGE_ARN_TARGET_1 = $(shell aws cloudformation describe-stacks --stack-name "$(REGIONAL_INFRA_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `EventBridgeArn`].OutputValue' --output text --region "$(TARGET_REGION_1)" )
deploy-eventbridge-target-1:
	aws cloudformation deploy --stack-name "$(EVENTBRIDGE_STACK_TARGET_1)" --template-file eventbridge.yaml --parameter-overrides EventBridgeArn="$(EVENTBRIDGE_ARN_TARGET_1)" --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --region us-west-2

deploy-target-1-attachment: VPC_ARN_TARGET_1 = $(shell aws cloudformation describe-stacks --stack-name "$(REGIONAL_INFRA_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `VPCArn`].OutputValue' --output text --region "$(TARGET_REGION_1)" )
deploy-target-1-attachment: SUBNET_ARN_TARGET_1 = $(shell aws cloudformation describe-stacks --stack-name "$(REGIONAL_INFRA_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `SubnetArn`].OutputValue' --output text --region "$(TARGET_REGION_1)" )
deploy-target-1-attachment: CORE_NETWORK_ID = $(shell aws cloudformation describe-stacks --stack-name "$(CLOUD_WAN_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region "$(GLOBAL_REGION)" )
deploy-target-1-attachment:
	aws cloudformation deploy --stack-name "$(CLOUD_WAN_ATTACHMENT_STACK)" --template-file cloud_wan_vpc_attachment.yaml --parameter-overrides EventBridgeArn="$(EVENTBRIDGE_ARN_TARGET_1)" VPCArn="$(VPC_ARN_TARGET_1)" SubnetArn="$(SUBNET_ARN_TARGET_1)" CoreNetworkId="$(CORE_NETWORK_ID)" DepartmentTagValue="$(VPC_DEPARTMENT_TAG)" --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --region "$(TARGET_REGION_1)"

# 3. Create TARGET_REGION_2 Lambda, VPC, EC2 instance, EventBridge Rule, and Cloud WAN VPC Attachment
deploy-target-2: deploy-resources-target-2 deploy-eventbridge-target-2 deploy-target-2-attachment

deploy-resources-target-2: IPAM_ID_TARGET_2 = $(shell aws cloudformation describe-stacks --stack-name "$(IPAM_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `HrAsiaPoolId`].OutputValue' --output text --region us-east-1 )
deploy-resources-target-2:
	aws cloudformation deploy --stack-name "$(REGIONAL_INFRA_STACK)" --template-file regional_infra.yaml --parameter-overrides IpamPoolId="$(IPAM_ID_TARGET_2)" VPCTagValue="$(VPC_DEPARTMENT_TAG)" --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --region "$(TARGET_REGION_2)"

deploy-eventbridge-target-2: EVENTBRIDGE_ARN_TARGET_2 = $(shell aws cloudformation describe-stacks --stack-name "$(REGIONAL_INFRA_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `EventBridgeArn`].OutputValue' --output text --region "$(TARGET_REGION_2)" )
deploy-eventbridge-target-2:
	aws cloudformation deploy --stack-name "$(EVENTBRIDGE_STACK_TARGET_2)" --template-file eventbridge.yaml --parameter-overrides EventBridgeArn="$(EVENTBRIDGE_ARN_TARGET_2)" --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --region us-west-2

deploy-target-2-attachment: VPC_ARN_TARGET_2 = $(shell aws cloudformation describe-stacks --stack-name "$(REGIONAL_INFRA_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `VPCArn`].OutputValue' --output text --region "$(TARGET_REGION_2)" )
deploy-target-2-attachment: SUBNET_ARN_TARGET_2 = $(shell aws cloudformation describe-stacks --stack-name "$(REGIONAL_INFRA_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `SubnetArn`].OutputValue' --output text --region "$(TARGET_REGION_2)" )
deploy-target-2-attachment: CORE_NETWORK_ID = $(shell aws cloudformation describe-stacks --stack-name "$(CLOUD_WAN_STACK)" --query 'Stacks[0].Outputs[?OutputKey == `CoreNetworkId`].OutputValue' --output text --region "$(GLOBAL_REGION)" )
deploy-target-2-attachment:
	aws cloudformation deploy --stack-name "$(CLOUD_WAN_ATTACHMENT_STACK)" --template-file cloud_wan_vpc_attachment.yaml --parameter-overrides EventBridgeArn="$(EVENTBRIDGE_ARN_TARGET_1)" VPCArn="$(VPC_ARN_TARGET_2)" SubnetArn="$(SUBNET_ARN_TARGET_2)" CoreNetworkId="$(CORE_NETWORK_ID)" DepartmentTagValue="$(VPC_DEPARTMENT_TAG)" --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset --region "$(TARGET_REGION_2)"

# 4. --------- Clean Up ---------------

# Undeploy all - targets, Cloud WAN, IPAM
undeploy: undeploy-target-1 undeploy-target-2 undeploy-cloud-wan undeploy-ipam

# Remove target 1
undeploy-target-1: 
	aws cloudformation delete-stack --stack-name "$(CLOUD_WAN_ATTACHMENT_STACK)" --region "$(TARGET_REGION_1)"
	aws cloudformation delete-stack --stack-name "$(EVENTBRIDGE_STACK_TARGET_1)" --region us-west-2
	aws cloudformation delete-stack --stack-name "$(REGIONAL_INFRA_STACK)" --region "$(TARGET_REGION_1)"
	aws cloudformation wait stack-delete-complete --stack-name "$(CLOUD_WAN_ATTACHMENT_STACK)" --region "$(TARGET_REGION_1)"
	aws cloudformation wait stack-delete-complete --stack-name "$(EVENTBRIDGE_STACK_TARGET_1)" --region us-west-2
	aws cloudformation wait stack-delete-complete --stack-name "$(REGIONAL_INFRA_STACK)" --region "$(TARGET_REGION_1)"

# Remove target 2
undeploy-target-2:
	aws cloudformation delete-stack --stack-name "$(CLOUD_WAN_ATTACHMENT_STACK)" --region "$(TARGET_REGION_2)"
	aws cloudformation delete-stack --stack-name "$(EVENTBRIDGE_STACK_TARGET_2)" --region us-west-2
	aws cloudformation delete-stack --stack-name "$(REGIONAL_INFRA_STACK)" --region "$(TARGET_REGION_2)"
	aws cloudformation wait stack-delete-complete --stack-name "$(CLOUD_WAN_ATTACHMENT_STACK)" --region "$(TARGET_REGION_2)"
	aws cloudformation wait stack-delete-complete --stack-name "$(EVENTBRIDGE_STACK_TARGET_2)" --region us-west-2
	aws cloudformation wait stack-delete-complete --stack-name "$(REGIONAL_INFRA_STACK)" --region "$(TARGET_REGION_2)"

#5. Remove CloudWAN and IPAM
undeploy-cloud-wan:
	aws cloudformation delete-stack --stack-name "$(CLOUD_WAN_STACK)" --region "$(GLOBAL_REGION)"
	aws cloudformation wait stack-delete-complete --stack-name "$(CLOUD_WAN_STACK)" --region "$(GLOBAL_REGION)"
undeploy-ipam:
	aws cloudformation delete-stack --stack-name "$(IPAM_STACK)" --region "$(GLOBAL_REGION)"
	aws cloudformation wait stack-delete-complete --stack-name "$(IPAM_STACK)" --region "$(GLOBAL_REGION)"
