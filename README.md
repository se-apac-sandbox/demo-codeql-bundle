# demo-codeql-bundle

This bundle uses the new codeQL qlpacks mechanism, customizations.qll feature and suite helpers to create a run-all version of codeQL bundle for evaluating the full code scanning set for codeQL. The customizations included here try to reflect a zero trust threat model and consider local sources, filenames and ajax calls as taint data for the codeQL queries to highlight security flaws during a SAST scan.

To use, please download one of the releases, unzip and set to path for the codeQL cli. For GitHub actions, use the `tools: <bundle-url>` param in the codeQL init action, which will use the bundle file from the specified release url and run codeQL. Teams can use further config files to exclude queries being run based on regex or metadata of the codeQL queries they'd like to exclude. 
