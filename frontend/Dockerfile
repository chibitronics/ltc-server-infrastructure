FROM nginx:stable
RUN apt-get update && apt-get install -y openssl && apt-get clean && rm -rf /var/lib/apt
COPY app.conf /etc/nginx/conf.d/
COPY entrypoint.sh /
CMD ["/entrypoint.sh"]
