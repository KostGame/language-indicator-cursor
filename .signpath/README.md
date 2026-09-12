# SignPath onboarding

This directory is reserved for SignPath origin/build policy files after the project is accepted for Open Source Code Signing.

The exact path required by SignPath is:

`.signpath/policies/<project-slug>/<signing-policy-slug>.yml`

The project slug, signing policy slug, organization ID, API token secret name, and artifact configuration are intentionally not guessed or committed before SignPath creates/approves the project.

Once those values exist, the release workflow should:

1. compile and test on a GitHub-hosted Windows runner;
2. upload the unsigned release artifact to GitHub Actions;
3. submit that GitHub artifact to SignPath using origin verification;
4. wait for the manually approved signing request;
5. download the signed artifact;
6. verify Authenticode status and expected product metadata;
7. package and publish only the signed artifact.

No private signing key should be stored in this repository.
