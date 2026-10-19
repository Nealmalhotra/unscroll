FROM node:25-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=8787 DATA_FILE=/data/db.json
COPY package.json ./
COPY src ./src
RUN mkdir -p /data && chown node:node /data
USER node
VOLUME ["/data"]
EXPOSE 8787
CMD ["node", "src/server.js"]
