const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, ScanCommand } = require("@aws-sdk/lib-dynamodb");
const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { v4: uuidv4 } = require('uuid');

const client = new DynamoDBClient({});
const ddbDocClient = DynamoDBDocumentClient.from(client);
const snsClient = new SNSClient({});
const s3Client = new S3Client({});

const EVENTS_TABLE = process.env.EVENTS_TABLE;
const SUBSCRIPTIONS_TABLE = process.env.SUBSCRIPTIONS_TABLE;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;
const S3_BUCKET = process.env.S3_BUCKET;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
};

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  const { httpMethod, pathParameters, body } = event;
  
  try {
    switch (httpMethod) {
      case 'POST':
        if (event.routeKey === 'POST /submit-event') {
          return await handleSubmitEvent(JSON.parse(body || '{}'));
        }
        break;
        
      case 'GET':
        if (event.routeKey === 'GET /events') {
          return await handleGetEvents();
        } else if (event.routeKey.startsWith('GET /events/')) {
          const eventId = pathParameters?.eventId;
          return await handleGetEvent(eventId);
        }
        break;
        
      case 'OPTIONS':
        return {
          statusCode: 200,
          headers: corsHeaders,
          body: ''
        };
    }
    
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

async function handleSubmitEvent(eventData) {
  const { 
    title, 
    date, 
    time, 
    location, 
    category, 
    description, 
    organizerEmail 
  } = eventData;
  
  // Validate required fields
  if (!title || !date || !time || !location || !category || !description || !organizerEmail) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'All fields are required' })
    };
  }
  
  const eventId = uuidv4();
  const now = new Date().toISOString();
  
  const newEvent = {
    eventId,
    title,
    date,
    time,
    location,
    category,
    description,
    organizerEmail,
    submittedAt: now,
    status: 'active'
  };
  
  // Store event in DynamoDB
  await ddbDocClient.send(new PutCommand({
    TableName: EVENTS_TABLE,
    Item: newEvent
  }));
  
  // Store event as JSON file in S3
  try {
    await s3Client.send(new PutObjectCommand({
      Bucket: S3_BUCKET,
      Key: `events/${eventId}.json`,
      Body: JSON.stringify(newEvent, null, 2),
      ContentType: 'application/json'
    }));
  } catch (s3Error) {
    console.error('Error saving to S3:', s3Error);
  }
  
  // Get interested subscribers and notify via SNS
  try {
    await notifySubscribers(newEvent);
  } catch (notificationError) {
    console.error('Error sending notifications:', notificationError);
  }
  
  return {
    statusCode: 201,
    headers: corsHeaders,
    body: JSON.stringify({
      message: 'Event submitted successfully',
      eventId,
      event: newEvent
    })
  };
}

async function handleGetEvents() {
  const result = await ddbDocClient.send(new ScanCommand({
    TableName: EVENTS_TABLE,
    FilterExpression: '#status = :status',
    ExpressionAttributeNames: {
      '#status': 'status'
    },
    ExpressionAttributeValues: {
      ':status': 'active'
    }
  }));
  
  // Sort by date and time
  const events = (result.Items || []).sort((a, b) => {
    const dateTimeA = new Date(`${a.date}T${a.time}`);
    const dateTimeB = new Date(`${b.date}T${b.time}`);
    return dateTimeA - dateTimeB;
  });
  
  return {
    statusCode: 200,
    headers: corsHeaders,
    body: JSON.stringify({
      events,
      count: events.length
    })
  };
}

async function handleGetEvent(eventId) {
  if (!eventId) {
    return {
      statusCode: 400,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Event ID is required' })
    };
  }
  
  const result = await ddbDocClient.send(new GetCommand({
    TableName: EVENTS_TABLE,
    Key: { eventId }
  }));
  
  if (!result.Item) {
    return {
      statusCode: 404,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'Event not found' })
    };
  }
  
  return {
    statusCode: 200,
    headers: corsHeaders,
    body: JSON.stringify({ event: result.Item })
  };
}

async function notifySubscribers(eventData) {
  // Get all subscribers
  const subscriptions = await ddbDocClient.send(new ScanCommand({
    TableName: SUBSCRIPTIONS_TABLE
  }));
  
  if (!subscriptions.Items || subscriptions.Items.length === 0) {
    console.log('No subscribers found');
    return;
  }
}
  
