# Use the official Node.js image
FROM node:18-alpine

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and install dependencies
COPY package.json package-lock.json ./
RUN npm install

# Copy the entire frontend application
COPY . .

# Expose port 3000 (Next.js default port)
EXPOSE 3000

# Run the development server
CMD ["npm", "run", "dev"]
