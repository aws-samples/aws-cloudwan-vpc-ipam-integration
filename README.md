## AWS Cloud WAN and VPC IPAM integration for end-to-end automated routing

AWS Cloud WAN is a service that you can use to build, manage, and monitor a unified global network that connects resources running across your cloud and on-premises environments. When you use Cloud WAN, you only need to update the routing tables of the VPCs to ensure network connectivity, and Cloud WAN ensures dynamic route propagation across multiple regions.

In this example, we'll see how to create a fully automated end-to-end routing architecture.

### Scenario and network topology
You have a global network, across 3 regions. Cloud WAN provides global network orchestration across these regions, and there are 3 Cloud WAN segments, one each for departments named Finance, Sales and HR. VPC IPAM stores the CIDRs assigned to each of the 3 departments. 

Whenever a VPC's attachment to Cloud WAN is created, this solution detects the 'attachment created' event, and automatically pushes the department's summary route into the VPC's routing table.

![Example Global Network](Global-Network.png)

### Prerequisites
1. Setup Cloud WAN, select the regions of your choice, and create 3 segments called Finance, Sales and HR
2. Create 3 VPC IPAM Pools named Finance, Sales and HR
3. Tag the Finance pool with the value 'finance', Sales pool with the value 'sales', and HR pool with the value 'hr'
4. Create an EventBridge rule
5. Repeat steps 6-10 for every target-region where you'd like to deploy this solution
6. Download the file named "update-VPC-RT.py", and deploy it as a lambda function in the target region. The lambda role must have the right IAM permissions to read from IPAM, and update VPC routing tables. 
7. Create an EventBridge Rule in the target-region with this event pattern:
{
  "account": ["<<Enter account number>>"],
  "source": ["aws.networkmanager"],
  "detail-type": ["Network Manager Topology Change"],
  "detail": {
    "changeType": ["VPC_ATTACHMENT_CREATED"]
  }
}
8. Set the target for this EventBridge rule as the lambda function deployed in the step above
9. Create an EventBridge rule in us-west-2 region with this event pattern:
{
  "account": ["<<Enter account number>>"],
  "detail-type": ["Network Manager Topology Change"],
  "detail": {
    "changeType": ["VPC_ATTACHMENT_CREATED"],
    "edgeLocation": ["<<enter target-region name, for example us-west-1>>"]
  }
}
10. Set the target of this rule as the EventBridge event default bus from the target region
11. Create a CloudWAN global network. Use this policy. This example policy uses us-east-1, us-west-1 and ap-southeast-1 as the target-regions. Please update the policy in case you're planning to use different regions.


### Steps
1. Create a VPC. Optionally, use VPC's department's IPAM pool to provide CIDR to the VPC: https://docs.aws.amazon.com/vpc/latest/ipam/create-vpc-ipam.html
2. Create an VPC attachment to the corresponding CloudWAN segment. Tag the Cloud WAN VPC attachment with key:value pair of "department:<department-name>". For example: "department:finance"
3. After a few minutes, check the VPC's associated routing table. It should have a route with a prefix list and target as the CloudWAN core-network. The prefix list should contain the VPC's department's CIDR.

### Considerations
1. This solution is useful when your VPCs have multiple exit points. In the scenario drawing, each VPC has 2 exit points. One towards the Cloud WAN core-network, and second towards AWS Direct Connect gateway
2. In addition to the networking constructs, there's pricing associated with EventBridge and with Lambda. Please check out service pricing pages for more details
