# demo-codeql-bundle
[![Custom CodeQL bundles - updated](https://github.com/amitgupta7/demo-codeql-bundle/actions/workflows/build-bundle-with-qlpacks.yml/badge.svg)](https://github.com/amitgupta7/demo-codeql-bundle/actions/workflows/build-bundle-with-qlpacks.yml)
## Provided as-is where-is for learning purposes only. Support is not available. 


This bundle uses the new codeQL qlpacks mechanism, customizations.qll feature and suite helpers to create a run-all version of codeQL bundle for evaluating the full code scanning set for codeQL. The customizations included here try to reflect a zero trust threat model and consider local sources, filenames and ajax calls as taint data for the codeQL queries to highlight security flaws during a SAST scan.

For this proof-of-concept, these modifications are applied only for go, python, java and javascript scans. Customizations for other languages will be added later. Also, some changes may be breaking, and hence testing the codeql bundle before using is the user's responsibility.    

To use, please download one of the releases, unzip and set to path for the codeQL cli. For GitHub actions, use the `tools: <bundle-url>` param in the codeQL init action, which will use the bundle file from the specified release url and run codeQL. Teams can use further config files to exclude queries being run based on regex or metadata of the codeQL queries they'd like to exclude. 

Ideally in a code scanning configuration, it is advised to run only the most relevant and high precision queries to reduce false positives. However depending on your code base and use-case (like security research) it may be required to run codeQL at a higher verbosity (and with a zero trust threat model). The below table provides an example of various possible configurations possible with these packs for a delebrately insecure application like webgoat. 

| Verbosity   |      Configuration      |  OWASP Webgoat</BR> Results |
|----------|-------------|:------:|
| default |  no changes to the codeql init action | 1x |
| level 1 |    `queries: security-extended`   |   1.2x |
| level 2 |    `queries: security-and-quality`   |   1.5x |
| level 3 |    `tools: https://github.com/amitgupta7/demo-codeql-bundle/releases/download/codeql-bundle-20220214-60d0cbc/codeql-bundle.tar.gz`</br>`queries: security-extended`   |   2x |
| level 4 |    `tools: https://github.com/amitgupta7/demo-codeql-bundle/releases/download/codeql-bundle-20220214-60d0cbc/codeql-bundle.tar.gz`   |   5x |
| level 5 |    `tools: https://github.com/amitgupta7/demo-codeql-bundle/releases/download/codeql-bundle-20220214-60d0cbc/codeql-bundle.tar.gz`</br>`queries: security-and-quality`   |   10x |

Your mileage may vary with this, so use at your own risk. A good starting point may be to use the level 3 or level 4 configuration, and adjust up/down as required. The results may be further refined using query suites (see example [here](https://github.com/amitgupta7/codeql-runall-config)). If you need to export results from github for further analysis/pivoting/comparision see [this](https://github.com/amitgupta7/ghas-reports-action) action.
