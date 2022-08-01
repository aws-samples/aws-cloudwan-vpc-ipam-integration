import json
import boto3
import urllib
import logging
from botocore.vendored import requests

ec2 = boto3.client('ec2')
ec2r = boto3.resource('ec2')
nm = boto3.client('networkmanager')
logger = logging.getLogger(__name__)


def lambda_handler(event, context):
    #print("Event json passed to lambda: " + json.dumps(event, indent=2))
    #print (event["detail"]["changeType"])
    try:
        #print ("PRINTING DEFAULT ROUTE TABLE NOW.")
        if event["detail"]["changeType"] == "VPC_ATTACHMENT_CREATED":
            #print ("VPC add event detected. Updating default routing table.")
            vpcId = event["detail"]["vpcArn"].split("/")[1]
            coreNetworkArn = event["detail"]["coreNetworkArn"]
            defrt = get_vpc(vpcId)
            print ("PRINTING DEFAULT ROUTE TABLE NOW.")
            print(defrt)

            #vpcarn = (event["detail"]["vpcArn"])
            attachmentId = event["detail"]["attachmentArn"].split("/")[1]
            print ("ATTACHMENT ID IS.")
            print (attachmentId)
            attachment_tag = get_attachment_tag(attachmentId)
            print ("ATTACHMENT TAG IS.")
            print (attachment_tag)
            cidr = get_cidr(attachment_tag)
            # Updates made to working lambda on Apr-25
            plid = create_pl(attachment_tag, cidr)
            add_route(defrt, plid, coreNetworkArn)
            #add_route(defrt, cidr, coreNetworkArn)
        else:
            print (event["detail"]["changeType"])
    except Exception as e:
        logger.info(format(e))
    return {
        'statusCode': 200,
        #'body': json.dumps('Hello from Lambda!')
    }
def get_vpc(VPCID):
    print ("Inside get_vpc")
    print (VPCID)
    response = ec2.describe_route_tables(
      Filters=[
        {
          'Name': 'association.main',
          'Values': [ 'true' ]
        },
        {
          'Name': 'vpc-id',
          'Values': [ VPCID ]
        }
      ]
    )
    print("Printing the VPC Route Table ID ....")
    RouteTableID=response['RouteTables'][0]['RouteTableId']
    print(RouteTableID)
    return RouteTableID

def get_attachment_tag(ATTACHMENT_ID):
    print ("Inside get_attachment_tag.")
    try:
        response2 = nm.get_vpc_attachment(AttachmentId=ATTACHMENT_ID)
        #print (response2)
        tagList = response2["VpcAttachment"]["Attachment"]["Tags"]
        d = next((d for d in tagList if d.get("Key") == "Department"), None)
        print (d["Value"])
        return d["Value"]
    except Exception as e:
        logger.info('ERROR IS: {}'.format(e))
        
def get_cidr(ATTACHMENT_TAG):
    print ("Inside get_cidr")
    print (ATTACHMENT_TAG)
    poolResponse = ec2.describe_ipam_pools()
    pools = poolResponse["IpamPools"]
    #print(pools)
    for i in pools:
        for tags in i["Tags"]:
            if ATTACHMENT_TAG in tags.values():
                poolId = i["IpamPoolId"]
                print (poolId)
                break
    cidr = ec2.get_ipam_pool_cidrs(IpamPoolId=poolId)["IpamPoolCidrs"][0]["Cidr"]
    print (cidr)
    return cidr
    
def add_route(defrt, plid, coreNetworkArn):
    print ("Inside add_route")
    print (plid)
    try: 
        defrtobj = ec2r.RouteTable(defrt)
        route_obj = defrtobj.create_route(DestinationPrefixListId=plid, CoreNetworkArn=coreNetworkArn)
        print ("JOB DONE!")
    except Exception as e:
        logger.info('ERROR IS: {}'.format(e))
        
def create_pl(plname, cidr):
    print ("Inside create_pl")
    print (plname)
    try:
        existing_pl = ec2.describe_managed_prefix_lists(Filters=[{'Name': 'prefix-list-name', 'Values': [plname]}])
        print (existing_pl["PrefixLists"])
        if (existing_pl["PrefixLists"]):
            print ("PL EXISTS.")
            print (existing_pl["PrefixLists"][0]["PrefixListId"])
            return existing_pl["PrefixLists"][0]["PrefixListId"]
        else:
            route_entry = [{'Cidr': cidr, 'Description': 'Fetched from VPC IPAM'}]
            pl = ec2.create_managed_prefix_list(PrefixListName=plname, Entries=route_entry, MaxEntries=10, AddressFamily='IPv4')
            return pl["PrefixList"]["PrefixListId"]
    except Exception as e:
        logger.info('ERROR IS: {}'.format(e))
