import os
import boto3
import pytest
from moto import mock_aws

@pytest.fixture
def table():
    os.environ["TABLE_NAME"] = "resume-counter"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
    with mock_aws():
        db = boto3.resource("dynamodb")
        t = db.create_table(
            TableName="resume-counter",
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        yield t
        
def test_counter_increments(table):
    import importlib
    import app
    
    importlib.reload(app)
    first = app.lambda_handler({}, None)
    second = app.lambda_handler({}, None)
    assert '"count": 1' in first["body"]
    assert '"count": 2' in second["body"]