import azure.functions as func
from function_app import GetResumeCounter
from unittest.mock import patch, MagicMock

@patch('function_app.TableClient.from_connection_string')
@patch.dict('os.environ', {"COSMOS_CONNECTION_STRING": "fake_string"})
def test_GetResumeCounter(mock_table_client):
    # 1. Arrange: Setup the fake database response
    mock_client_instance = MagicMock()
    mock_table_client.return_value = mock_client_instance
    
    # Fake an existing entity with a count of 5
    mock_client_instance.get_entity.return_value = {
        "PartitionKey": "resume",
        "RowKey": "visitor_count",
        "Count": 5
    }

    # Setup a fake HTTP Request
    req = func.HttpRequest(
        method='GET',
        body=None,
        url='/api/GetResumeCounter'
    )

    # 2. Act: Run the function
    resp = GetResumeCounter(req)

    # 3. Assert: Verify the results
    assert resp.status_code == 200
    assert resp.get_body() == b'6' # It should add 1 to the mock count of 5
    
    # Verify the database update method was called once
    mock_client_instance.update_entity.assert_called_once()