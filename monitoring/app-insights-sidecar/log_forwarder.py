#!/usr/bin/env python3
"""
Redis Log Forwarder to Azure Application Insights
------------------------------------------------
This script reads Redis logs and forwards them to Azure Application Insights.
It's designed to run as a sidecar container alongside Redis Stack.
"""

import os
import time
import logging
import re
import json
from datetime import datetime
import pytz
from pythonjsonlogger import jsonlogger
from opencensus.ext.azure.log_exporter import AzureLogHandler

# Configuration from environment variables
REDIS_LOG_PATH = os.environ.get('REDIS_LOG_PATH', '/var/log/redis/redis.log')
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'info').upper()
APP_INSIGHTS_CONNECTION_STRING = os.environ.get('APP_INSIGHTS_CONNECTION_STRING', '')
APP_INSIGHTS_ROLE_NAME = os.environ.get('APP_INSIGHTS_ROLE_NAME', 'redis-stack')
APP_INSIGHTS_ROLE_INSTANCE = os.environ.get('APP_INSIGHTS_ROLE_INSTANCE', 'redis-1')
SAMPLING_PERCENTAGE = float(os.environ.get('SAMPLING_PERCENTAGE', '100'))

# Redis log pattern: timestamp pid role severity message
REDIS_LOG_PATTERN = re.compile(r'(\d+:\d+:\d+\.\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(.*)')

# Setup logging
log_level = getattr(logging, LOG_LEVEL, logging.INFO)
logger = logging.getLogger('redis-log-forwarder')
logger.setLevel(log_level)

# Console handler for the forwarder's own logs
console_handler = logging.StreamHandler()
console_handler.setLevel(log_level)
console_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
console_formatter = logging.Formatter(console_format)
console_handler.setFormatter(console_formatter)
logger.addHandler(console_handler)

# Setup Azure Application Insights if connection string is provided
if APP_INSIGHTS_CONNECTION_STRING:
    # Create a custom format that includes Redis-specific fields
    class CustomJsonFormatter(jsonlogger.JsonFormatter):
        def add_fields(self, log_record, record, message_dict):
            super(CustomJsonFormatter, self).add_fields(log_record, record, message_dict)
            log_record['app'] = APP_INSIGHTS_ROLE_NAME
            log_record['instance'] = APP_INSIGHTS_ROLE_INSTANCE
            log_record['level'] = record.levelname
            log_record['logger'] = record.name
            
            # Add timestamp in ISO format
            tz = pytz.timezone('UTC')
            now = datetime.now(tz)
            log_record['timestamp'] = now.isoformat()
            
            # Add custom dimensions for Redis logs if they exist
            if hasattr(record, 'redis_pid'):
                log_record['redis_pid'] = record.redis_pid
            if hasattr(record, 'redis_role'):
                log_record['redis_role'] = record.redis_role
    
    # Configure Azure Log Handler
    azure_handler = AzureLogHandler(
        connection_string=APP_INSIGHTS_CONNECTION_STRING,
        logging_sampling_rate=SAMPLING_PERCENTAGE/100.0
    )
    
    # Apply custom JSON formatter
    formatter = CustomJsonFormatter('%(timestamp)s %(level)s %(name)s %(message)s')
    azure_handler.setFormatter(formatter)
    logger.addHandler(azure_handler)
    
    logger.info(f"Azure Application Insights logging enabled with sampling rate: {SAMPLING_PERCENTAGE}%")
else:
    logger.warning("Azure Application Insights connection string not provided. Logs will only be printed to console.")

def parse_redis_log_line(line):
    """Parse a Redis log line into components."""
    match = REDIS_LOG_PATTERN.match(line)
    if match:
        timestamp, pid, role, severity, message = match.groups()
        return {
            'timestamp': timestamp,
            'pid': pid,
            'role': role,
            'severity': severity,
            'message': message
        }
    return None

def map_redis_severity_to_python(severity):
    """Map Redis log severity to Python logging levels."""
    severity = severity.lower()
    if severity == 'debug':
        return logging.DEBUG
    elif severity == 'verbose':
        return logging.INFO
    elif severity == 'notice':
        return logging.INFO
    elif severity == 'warning':
        return logging.WARNING
    else:  # Default for errors and unknown levels
        return logging.ERROR

def follow_log_file(file_path):
    """Follow the log file similar to 'tail -f'."""
    try:
        with open(file_path, 'r') as file:
            # Go to the end of the file
            file.seek(0, 2)
            while True:
                line = file.readline()
                if not line:
                    time.sleep(0.1)  # Sleep briefly
                    continue
                yield line
    except FileNotFoundError:
        logger.error(f"Log file not found: {file_path}")
        time.sleep(5)  # Wait before retrying
        yield from follow_log_file(file_path)

def main():
    """Main function to read Redis logs and forward to App Insights."""
    logger.info(f"Starting Redis log forwarder, watching: {REDIS_LOG_PATH}")
    
    while True:
        try:
            for line in follow_log_file(REDIS_LOG_PATH):
                line = line.strip()
                if not line:
                    continue
                    
                parsed = parse_redis_log_line(line)
                if parsed:
                    # Create a log record with Redis metadata
                    log_level = map_redis_severity_to_python(parsed['severity'])
                    
                    # Create a custom log record
                    record = logging.LogRecord(
                        name='redis',
                        level=log_level,
                        pathname='',
                        lineno=0,
                        msg=parsed['message'],
                        args=(),
                        exc_info=None
                    )
                    
                    # Add Redis specific information as attributes
                    record.redis_pid = parsed['pid']
                    record.redis_role = parsed['role']
                    
                    # Process the record with all handlers
                    logger.handle(record)
                else:
                    # For lines that don't match the pattern, log as is
                    logger.info(f"Redis log: {line}")
        except Exception as e:
            logger.error(f"Error processing logs: {str(e)}")
            time.sleep(5)  # Wait before retrying

if __name__ == "__main__":
    main()
