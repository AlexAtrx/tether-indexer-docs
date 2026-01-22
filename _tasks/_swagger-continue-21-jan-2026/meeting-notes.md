We ran into a problem with the Swagger response validation. The generated Swagger schema checks every response against the defined model. If a field is missing or the shape is different the server returns a 422 error. That would break production because our Mongo collections are schema‑less and many optional fields are often empty.

Osman warned that hard‑coding a 422 on mismatches could stop traffic in production. He suggested we should still notice the mismatches but not reject the request. He proposed logging a warning whenever a response doesn’t fit the Swagger definition and monitoring those warnings.

Francesco preferred to turn the validation off completely for now. He felt the risk of 422 errors outweighs the benefit of strict enforcement until the schema stabilises.

The team settled on a middle‑ground solution. We will keep request validation active. For responses we will add a middleware that checks the payload against the Swagger schema, logs a warning if there’s a mismatch, and lets the response go through. The warning will be sent to our logging system so we can track how often it happens and decide later whether to tighten the rules. This approach can be merged into the Swagger repository today and approved by the team.

## In short

- Swagger implementation first iteration; need to document current behavior without enforcing response validation.
- Or the middle ground that Osman is talking about.
