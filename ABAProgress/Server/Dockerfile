FROM node:22-alpine
WORKDIR /app
COPY --chown=node:node server.mjs GUIDE_SCRIPT.md ./
USER node
ENV NODE_ENV=production LISTEN_HOST=0.0.0.0 PORT=8787
EXPOSE 8787
CMD ["node", "server.mjs"]
