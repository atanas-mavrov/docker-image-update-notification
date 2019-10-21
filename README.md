# docker-image-update-notification
If you have (many) docker images on your server(s) and want to always be updated, this script will help you check them periodically

# Usage
1. Change your email in the last line of the script
2. Execute script with image and version as parameters
```bash
./update_notification.sh sentry latest
```
If there is new version you will receive an email notification
