// subscription/function.js

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand, DeleteCommand, ScanCommand } = require("@aws-sdk/lib-dynamodb");
const { SNSClient, SubscribeCommand, UnsubscribeCommand } = require("@aws-sdk/client-sns");

const client = new DynamoDBClient({});
const ddbDocClient = DynamoDBDocumentClient.from(client);
const snsClient = new SNSClient({});

const SUBSCRIPTIONS_TABLE = process.env.SUBSCRIPTIONS_TABLE;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS'
};

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  // SỬA LỖI: Lấy ra httpMethod và resource từ event
  const { httpMethod, resource, pathParameters, body } = event;
  
  try {
    // SỬA LỖI: Thay thế switch(httpMethod) bằng các câu lệnh if tường minh hơn
    if (httpMethod === 'POST' && resource === '/subscribe') {
        return await handleSubscribe(JSON.parse(body || '{}'));
    }
    
    if (httpMethod === 'GET' && resource === '/subscriptions') {
        return await handleGetSubscriptions();
    }
    
    // Terraform route là /subscribe/{email}
    if (httpMethod === 'DELETE' && resource === '/subscribe/{email}') {
        const email = pathParameters?.email;
        return await handleUnsubscribe(email);
    }

    if (httpMethod === 'OPTIONS') {
        return {
          statusCode: 204, // Sử dụng 204 cho OPTIONS là chuẩn hơn
          headers: corsHeaders,
          body: ''
        };
    }
    
    // Nếu không có route nào khớp, trả về 404
    return {
      statusCode: 404,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Not Found' })
    };
    
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        message: 'Internal server error',
        error: error.message 
      })
    };
  }
};

async function handleSubscribe(subscriptionData) {
  const { name, email, interests } = subscriptionData;
  
  if (!name || !email) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Name and email are required' })
    };
  }
  
  try {
    const existingSubscription = await ddbDocClient.send(new GetCommand({
      TableName: SUBSCRIPTIONS_TABLE,
      Key: { email }
    }));
    
    if (existingSubscription.Item) {
      await ddbDocClient.send(new PutCommand({
        TableName: SUBSCRIPTIONS_TABLE,
        Item: {
          email,
          name,
          interests: interests || [],
          subscribedAt: existingSubscription.Item.subscribedAt,
          updatedAt: new Date().toISOString(),
          snsSubscriptionArn: existingSubscription.Item.snsSubscriptionArn
        }
      }));
      
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({ 
          message: 'Subscription updated successfully',
          email 
        })
      };
    }
  } catch (error) {
    console.log('No existing subscription found, creating new one');
  }
  
  let snsSubscriptionArn = null;
  try {
    const snsResponse = await snsClient.send(new SubscribeCommand({
      TopicArn: SNS_TOPIC_ARN,
      Protocol: 'email',
      Endpoint: email
    }));
    snsSubscriptionArn = snsResponse.SubscriptionArn;
  } catch (error) {
    console.error('Error subscribing to SNS:', error);
  }
  
  await ddbDocClient.send(new PutCommand({
    TableName: SUBSCRIPTIONS_TABLE,
    Item: {
      email,
      name,
      interests: interests || [],
      subscribedAt: new Date().toISOString(),
      snsSubscriptionArn
    }
  }));
  
  return {
    statusCode: 201,
    headers: corsHeaders,
    body: JSON.stringify({ 
      message: 'Subscription created successfully',
      email,
      note: 'Please check your email to confirm the SNS subscription'
    })
  };
}

async function handleGetSubscriptions() {
  const result = await ddbDocClient.send(new ScanCommand({
    TableName: SUBSCRIPTIONS_TABLE
  }));
  
  return {
    statusCode: 200,
    headers: corsHeaders,
    body: JSON.stringify({ 
      subscriptions: result.Items || [],
      count: result.Count 
    })
  };
}

async function handleUnsubscribe(email) {
  if (!email) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Email is required' })
    };
  }
  
  try {
    const subscription = await ddbDocClient.send(new GetCommand({
      TableName: SUBSCRIPTIONS_TABLE,
      Key: { email: decodeURIComponent(email) }
    }));
    
    if (!subscription.Item) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Subscription not found' })
      };
    }
    
    if (subscription.Item.snsSubscriptionArn && 
        subscription.Item.snsSubscriptionArn !== 'pending confirmation') {
      try {
        await snsClient.send(new UnsubscribeCommand({
          SubscriptionArn: subscription.Item.snsSubscriptionArn
        }));
      } catch (error) {
        console.error('Error unsubscribing from SNS:', error);
      }
    }
    
    await ddbDocClient.send(new DeleteCommand({
      TableName: SUBSCRIPTIONS_TABLE,
      Key: { email: decodeURIComponent(email) }
    }));
    
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Unsubscribed successfully' })
    };
    
  } catch (error) {
    console.error('Error unsubscribing:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Error unsubscribing' })
    };
  }
}