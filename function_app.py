import os
import azure.functions as func
import datetime
import json

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)