console.log(
  `Loading code for ${process.env.TARGET_FN_NAME} from ${
    process.env.BUCKET_NAME
  }/${process.env.BUCKET_KEY}`
);

var AWS = require("aws-sdk");
var lambda = new AWS.Lambda();

exports.handler = function(event, context) {
  const key = event.Records[0].s3.object.key;
  const bucket = event.Records[0].s3.bucket.name;
  const version = event.Records[0].s3.object.versionId;

  if (
    bucket == process.env.BUCKET_NAME &&
    key == process.env.BUCKET_KEY &&
    version
  ) {
    var functionName = process.env.TARGET_FN_NAME;
    console.log("uploaded to lambda function: " + functionName);
    var params = {
      FunctionName: functionName,
      S3Key: key,
      S3Bucket: bucket,
      S3ObjectVersion: version
    };
    lambda.updateFunctionCode(params, function(err, data) {
      if (err) {
        console.log(err, err.stack);
        context.fail(err);
      } else {
        console.log(data);
        context.succeed(data);
      }
    });
  } else {
    context.succeed(
      "skipping zip " +
        key +
        " in bucket " +
        bucket +
        " with version " +
        version
    );
  }
};
