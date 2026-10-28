import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin":
        os.environ.get("ALLOWED_ORIGIN", "*"),
}

def lambda_handler(event, context):
    try:
        result = table.update_item (
            Key={"id": "visits"},
            UpdateExpression="ADD #c :inc",
            ExpressionAttributeNames={"#c": "count"},
            ExpressionAttributeValues={":inc": 1},
            ReturnValues="UPDATED_NEW",
        )
        count = int(result["Attributes"]["count"])
        return {
            "statusCode": 200,
            "headers": HEADERS,
            "body": json.dumps({"count": count}),
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "headers": HEADERS,
            "body": json.dumps({"error": "internal error"}),
        }