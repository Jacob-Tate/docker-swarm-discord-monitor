#!/usr/bin/env python3
"""
Docker Swarm Event Monitor with Discord Webhook Notifications
Monitors container start/stop events and sends Discord notifications
"""

import json
import logging
import os
import socket
import sys
import time
from datetime import datetime
from typing import Dict, Any

import docker
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Configuration
DISCORD_WEBHOOK_URL = os.getenv('DISCORD_WEBHOOK_URL', '')
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
RETRY_ATTEMPTS = int(os.getenv('RETRY_ATTEMPTS', '3'))
TIMEOUT_SECONDS = int(os.getenv('TIMEOUT_SECONDS', '30'))
DISCORD_USERNAME = os.getenv('DISCORD_USERNAME', 'Docker Swarm Monitor')
DISCORD_AVATAR_URL = os.getenv('DISCORD_AVATAR_URL', 'https://raw.githubusercontent.com/docker/compose/v2/logo.png')
DEDUP_WINDOW = int(os.getenv('DEDUP_WINDOW', '10'))  # seconds

# Setup logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper()),
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class DockerSwarmDiscordMonitor:
    def __init__(self, discord_webhook_url: str):
        self.discord_webhook_url = discord_webhook_url
        self.node_name = socket.gethostname()
        self.session = self._create_session()
        # Deduplication cache: {container_name: {event_type: timestamp}}
        self.recent_events = {}
        self.dedup_window = DEDUP_WINDOW  # seconds
        
        try:
            self.client = docker.from_env()
            # Verify we're in a swarm
            self.client.nodes.list()
            logger.info(f"Connected to Docker Swarm on node: {self.node_name}")
        except docker.errors.APIError as e:
            logger.error(f"Not connected to Docker Swarm: {e}")
            sys.exit(1)
        except Exception as e:
            logger.error(f"Failed to connect to Docker: {e}")
            sys.exit(1)
    
    def _create_session(self) -> requests.Session:
        """Create HTTP session with retry strategy"""
        session = requests.Session()
        
        retry_strategy = Retry(
            total=RETRY_ATTEMPTS,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        
        return session
    
    def get_embed_color(self, event_type: str) -> int:
        """Get Discord embed color based on event type"""
        colors = {
            'started': 0x00ff00,  # Green
            'stopped': 0xff0000,  # Red
            'restarted': 0xffaa00,  # Orange
        }
        return colors.get(event_type, 0x888888)  # Default gray
    
    def get_status_emoji(self, event_type: str) -> str:
        """Get emoji based on event type"""
        emojis = {
            'started': '🟢',
            'stopped': '🔴',
            'restarted': '🟡',
        }
        return emojis.get(event_type, '⚪')
    
    def create_discord_payload(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create Discord webhook payload with embeds"""
        event_type = event_data['event_type']
        emoji = self.get_status_emoji(event_type)
        color = self.get_embed_color(event_type)
        
        # Create the embed
        embed = {
            "title": f"{emoji} Container {event_type.title()}",
            "color": color,
            "timestamp": event_data['timestamp'],
            "fields": [
                {
                    "name": "📦 Container",
                    "value": f"`{event_data['container_name']}`",
                    "inline": True
                },
                {
                    "name": "🔧 Service",
                    "value": f"`{event_data['service_name']}`",
                    "inline": True
                },
                {
                    "name": "🖥️ Node",
                    "value": f"`{event_data['node_name']}`",
                    "inline": True
                }
            ],
            "footer": {
                "text": "Docker Swarm Monitor",
                "icon_url": "https://raw.githubusercontent.com/docker/compose/v2/logo.png"
            }
        }
        
        # Add description based on event type
        if event_type == 'started':
            embed["description"] = f"✅ Container is now running"
        elif event_type == 'stopped':
            embed["description"] = f"❌ Container has stopped"
        elif event_type == 'restarted':
            embed["description"] = f"🔄 Container has been restarted"
        
        # Main payload
        payload = {
            "username": DISCORD_USERNAME,
            "avatar_url": DISCORD_AVATAR_URL,
            "embeds": [embed]
        }
        
        return payload
    
    def send_discord_webhook(self, event_data: Dict[str, Any]) -> bool:
        """Send Discord webhook notification"""
        try:
            payload = self.create_discord_payload(event_data)
            
            response = self.session.post(
                self.discord_webhook_url,
                json=payload,
                timeout=TIMEOUT_SECONDS,
                headers={'Content-Type': 'application/json'}
            )
            response.raise_for_status()
            
            logger.info(f"Discord webhook sent successfully for {event_data['event_type']}: {event_data['container_name']}")
            return True
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Discord webhook failed for {event_data['event_type']}: {event_data['container_name']} - {e}")
            return False
    
    def send_startup_notification(self):
        """Send a notification when the monitor starts"""
        startup_embed = {
            "title": "🚀 Docker Swarm Monitor Started",
            "color": 0x0099ff,  # Blue
            "timestamp": datetime.utcnow().isoformat(),
            "fields": [
                {
                    "name": "🖥️ Node",
                    "value": f"`{self.node_name}`",
                    "inline": True
                },
                {
                    "name": "📊 Status",
                    "value": "Monitoring Active",
                    "inline": True
                }
            ],
            "description": "Now monitoring container start/stop events",
            "footer": {
                "text": "Docker Swarm Monitor",
                "icon_url": "https://raw.githubusercontent.com/docker/compose/v2/logo.png"
            }
        }
        
        payload = {
            "username": DISCORD_USERNAME,
            "avatar_url": DISCORD_AVATAR_URL,
            "embeds": [startup_embed]
        }
        
        try:
            response = self.session.post(
                self.discord_webhook_url,
                json=payload,
                timeout=TIMEOUT_SECONDS
            )
            response.raise_for_status()
            logger.info("Startup notification sent to Discord")
        except Exception as e:
            logger.error(f"Failed to send startup notification: {e}")
    
    def is_duplicate_event(self, container_name: str, event_type: str, event_time: float) -> bool:
        """Check if this event is a duplicate within the deduplication window"""
        now = time.time()
        
        # Clean old entries
        for container in list(self.recent_events.keys()):
            for event in list(self.recent_events[container].keys()):
                if now - self.recent_events[container][event] > self.dedup_window:
                    del self.recent_events[container][event]
            if not self.recent_events[container]:
                del self.recent_events[container]
        
        # Check if this is a duplicate
        if container_name in self.recent_events:
            if event_type in self.recent_events[container_name]:
                last_time = self.recent_events[container_name][event_type]
                if event_time - last_time < self.dedup_window:
                    return True
        
        # Record this event
        if container_name not in self.recent_events:
            self.recent_events[container_name] = {}
        self.recent_events[container_name][event_type] = event_time
        
        return False
    
    def process_event(self, event: Dict[str, Any]) -> None:
        """Process a Docker event and send Discord notification if relevant"""
        try:
            action = event.get('Action', '')
            actor = event.get('Actor', {})
            attributes = actor.get('Attributes', {})
            event_time = event.get('time', time.time())
            
            container_name = attributes.get('name', 'unknown')
            service_name = attributes.get('com.docker.swarm.service.name', '')
            
            # Skip non-swarm containers
            if not service_name:
                return
            
            # Only process start/die events (die covers all container stops)
            if action not in ['start', 'die']:
                return
            
            # Map die to stopped for consistency
            event_type = 'stopped' if action == 'die' else 'started'
            
            # Check for duplicate events
            if self.is_duplicate_event(container_name, event_type, event_time):
                logger.debug(f"Skipping duplicate {event_type} event for {container_name}")
                return
            
            timestamp = datetime.fromtimestamp(event_time).isoformat()
            
            event_data = {
                'event_type': event_type,
                'container_name': container_name,
                'service_name': service_name,
                'node_name': self.node_name,
                'timestamp': timestamp,
                'swarm_mode': True
            }
            
            logger.info(f"Container {event_type.upper()}: {container_name} (service: {service_name})")
            self.send_discord_webhook(event_data)
            
        except Exception as e:
            logger.error(f"Error processing event: {e}")
    
    def start_monitoring(self) -> None:
        """Start monitoring Docker events"""
        logger.info("Starting Docker Swarm event monitoring...")
        logger.info(f"Discord webhook configured: {bool(self.discord_webhook_url)}")
        logger.info(f"Deduplication window: {self.dedup_window} seconds")
        
        # Send startup notification
        self.send_startup_notification()
        
        try:
            events = self.client.events(
                filters={
                    'type': 'container',
                    'event': ['start', 'die']
                },
                decode=True
            )
            
            for event in events:
                self.process_event(event)
                
        except KeyboardInterrupt:
            logger.info("Monitoring stopped by user")
            
            # Send shutdown notification
            shutdown_embed = {
                "title": "🛑 Docker Swarm Monitor Stopped",
                "color": 0xff9900,  # Orange
                "timestamp": datetime.utcnow().isoformat(),
                "fields": [
                    {
                        "name": "🖥️ Node",
                        "value": f"`{self.node_name}`",
                        "inline": True
                    }
                ],
                "description": "Container monitoring has been stopped",
                "footer": {
                    "text": "Docker Swarm Monitor",
                    "icon_url": "https://raw.githubusercontent.com/docker/compose/v2/logo.png"
                }
            }
            
            payload = {
                "username": DISCORD_USERNAME,
                "avatar_url": DISCORD_AVATAR_URL,
                "embeds": [shutdown_embed]
            }
            
            try:
                self.session.post(self.discord_webhook_url, json=payload, timeout=5)
            except:
                pass  # Don't fail on shutdown notification
                
        except Exception as e:
            logger.error(f"Error monitoring events: {e}")
            raise

def main():
    if not DISCORD_WEBHOOK_URL:
        logger.error("Please set DISCORD_WEBHOOK_URL environment variable")
        logger.error("Get your Discord webhook URL from: Server Settings > Integrations > Webhooks")
        sys.exit(1)
    
    monitor = DockerSwarmDiscordMonitor(DISCORD_WEBHOOK_URL)
    monitor.start_monitoring()

if __name__ == '__main__':
    main()
