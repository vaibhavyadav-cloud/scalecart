/** @type {import('next').NextConfig} */
const nextConfig = {
  // Static export: `next build` produces plain HTML/JS/CSS in ./out with
  // no Node.js server needed at runtime. That's what lets this be served
  // by a plain Nginx container (see Dockerfile) and, in production, pushed
  // straight to the S3 bucket that CloudFront fronts (terraform/modules/s3-cloudfront).
  output: "export",
  images: { unoptimized: true },
};

module.exports = nextConfig;
