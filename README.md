# SA assessment - AWS Fundamentals
 
This repository contains artefacts which help in building the infratructure required to complete the SA assessment.

The linux infrastructure has been built using terraform. 

This includes 
1. Provisioning ec2 instances, 
2. Provisioning ebs and attaching it using user-data 
3. Installing apache via user-data
4. Making changes to ensure that the index.html is served as requested
5. Ensuring security groups allow appropriate access - ssh & http
6. Provisioning elb with requested configuration
7. 
