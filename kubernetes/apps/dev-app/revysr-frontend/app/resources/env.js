window._ENV = {
  VITE_PUBLIC_POSTHOG_KEY: '${VITE_PUBLIC_POSTHOG_KEY}',
  VITE_PUBLIC_POSTHOG_HOST: 'https://eu.i.posthog.com',
  VITE_GATEWAY_BASE_URL: 'https://dev-gateway.${APP_DEV_SECRET_DOMAIN}',
  VITE_API_BASE_URL: 'https://dev-gateway.${APP_DEV_SECRET_DOMAIN}',
  VITE_KEYCLOAK_URL: 'https://dev-gateway.${APP_DEV_SECRET_DOMAIN}',
  VITE_KEYCLOAK_REALM: 'revysr',
  VITE_KEYCLOAK_CLIENT_ID: 'revysr-public-client',
  VITE_SIGNALR_HUB_URL: 'https://dev-gateway.${APP_DEV_SECRET_DOMAIN}/hubs'
};

