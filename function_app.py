import azure.functions as func
import logging
import os
from azure.data.tables import TableClient
from azure.core.exceptions import ResourceNotFoundError

logging.basicConfig(level=logging.INFO)
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="GetResumeCounter", auth_level=func.AuthLevel.ANONYMOUS)
def GetResumeCounter(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    connection_string = os.environ["COSMOS_CONNECTION_STRING"]
    table_name = "Counter"
    
    # Initialize the Table Client
    table_client = TableClient.from_connection_string(conn_str=connection_string, table_name=table_name)
    
    partition_key = "resume"
    row_key = "visitor_count"

    try:
        # Attempt to read the existing entity
        entity = table_client.get_entity(partition_key=partition_key, row_key=row_key)
        current_count = entity.get("Count", 0)
        new_count = current_count + 1
        
        # Update the entity with the new count
        entity["Count"] = new_count
        table_client.update_entity(mode="replace", entity=entity)
        
    except ResourceNotFoundError:
        # If it doesn't exist (first run), create it
        new_count = 1
        entity = {
            "PartitionKey": partition_key,
            "RowKey": row_key,
            "Count": new_count
        }
        table_client.create_entity(entity=entity)

    # Return the new count to the frontend
    return func.HttpResponse(
        str(new_count),
        status_code=200,
        mimetype="application/json"
    )