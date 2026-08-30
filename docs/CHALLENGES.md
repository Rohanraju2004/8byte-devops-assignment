Challenges Faced and Resolutions
Problems I hit while building this, how I worked them out, and what I took away.
________________________________________
1. WSL was using the Windows version of Node
npm install kept failing inside Ubuntu, and the error log pointed at a path under C:\Users\. Running which npm showed it was resolving to /mnt/c/Program Files/nodejs/npm.
WSL adds the Windows PATH onto the Linux PATH, so with Node not installed on the Linux side, the Windows binary was found instead.
I installed Node through apt and then ran hash -r, which clears the shell's memory of where commands live. Without that step the shell keeps using the old path even after the new binary is there.
Takeaway: in WSL, check which binary you are actually running before debugging its behaviour.
________________________________________
2. RDS naming rules are stricter than other services
terraform apply failed with first character of "identifier" must be a letter. My project name is 8byte-devops, which starts with a digit.
The same string had worked fine for VPC and subnet tags. RDS just has tighter rules.
I prefixed the RDS resources with db- rather than renaming the whole project.
Takeaway: AWS naming rules are per service, not global.
________________________________________
3. Terraform checks syntax, not AWS's rules
Right after fixing that, apply failed again on the database subnet group, which had the same digit-prefix problem. What made this interesting is that terraform validate and terraform plan had both passed.
By the time it failed, three security groups had already been created.
Terraform checks that your HCL is valid and that your references make sense. It does not know about per-service naming rules, which only get enforced by the AWS API at apply time. I applied the same fix and re-ran, and Terraform continued from where it stopped rather than starting over.
Takeaway: a passing plan does not guarantee a successful apply. Also, apply is not all-or-nothing. Partial state after a failure is normal, and re-running picks up from there.
________________________________________
4. Performance Insights is not available on small instances
I had enabled Performance Insights on the database, but db.t4g.micro does not support it, so it would have failed at apply.
I removed it and used CloudWatch RDS metrics instead: CPU, memory, storage and connection count.
Takeaway: instance size determines which features you can use. This was a tradeoff, the cheapest instance in exchange for less detailed query diagnostics.
________________________________________
5. The generated password broke the connection string
After deploying, /ready returned 503. The container was running and logging normally, but could not reach the database.
My first guess was SSL, since RDS forces it by default. That turned out to be wrong.
The problem was that my catch block returned a clean 503 but logged nothing, so there was no error to read. I connected to the instance through SSM and ran the same query manually inside the container, which finally printed the real error: ERR_INVALID_URL.
Looking at the container's environment variables showed why. The password RDS had generated contained a colon, and the URL parser treated it as a delimiter, so the connection string was malformed.
I stopped using a connection URL entirely and passed host, user, password and database name as separate environment variables instead. That avoids the encoding problem completely.
Takeaway: randomly generated passwords can contain characters that mean something in whatever format you put them in. Passing values as separate fields is safer than building one string. Also, my first guess was wrong, and following the actual error rather than the assumption is what fixed it.
________________________________________
6. My error handling hid the cause
Directly related to the above. The /ready and /items handlers caught database errors and returned tidy HTTP responses, but threw the error message away.
I added console.error(err.message) to both catch blocks. The client still gets a clean response, but the error now shows up in the container logs.
Takeaway: silent error handling is right for the user and useless for whoever has to fix it. An error you catch but never log is an outage you cannot diagnose.
________________________________________
7. OIDC role assumption kept being denied (not resolved)
I built the pipeline to authenticate to AWS using OIDC federation instead of stored keys. Every run failed with Not authorized to perform sts:AssumeRoleWithWebIdentity.
I worked through each condition:
•	Pulled the live trust policy with aws iam get-role and confirmed the repository string matched exactly
•	Confirmed the audience condition was sts.amazonaws.com
•	Confirmed the OIDC provider existed with the right URL and client ID
•	Confirmed the role ARN in the workflow matched the live role
•	Confirmed the workflow declared id-token: write
Everything visible was correct. I also found the provider's certificate thumbprint was out of date, and discovered that removing thumbprint_list from my Terraform did not remove it from AWS. Terraform treats it as computed, so deleting the argument means "stop managing this", not "clear it". I only caught that by checking the live resource with the CLI rather than trusting the plan. Updating the thumbprints directly did not fix it either.
With the deadline approaching I switched the pipeline to stored repository secrets rather than submit a pipeline that did not run. The OIDC role and trust policy are still in the repository.
What I would try next: declaring permissions at the job level rather than the workflow level, and retesting after a longer gap, since IAM is eventually consistent and the provider had been recreated shortly before each attempt.
Takeaway: the error names the action that failed but not which check rejected it, so you have to work through each condition. And terraform plan saying "no changes" does not mean the live resource matches what you intended.
I know stored credentials are the weaker option. They are long-lived, stay valid until manually revoked, and have to be rotated by hand, whereas OIDC issues short-lived credentials tied to one repository. Finishing that migration is my first priority.
________________________________________
8. The same config existed in two places and drifted
While switching from OIDC to stored credentials, I updated the credentials step in the build job but missed the identical one in the staging deploy job. The build passed and the deploy failed with the original error, which briefly looked like the fix had not worked at all.
I fixed both and used grep to confirm no stale config was left.
Takeaway: GitHub Actions has no way to share a step across jobs in one workflow, so identical config gets copied and then drifts apart. A reusable workflow would prevent that.
________________________________________
9. The deploy stopped the app without restarting it properly
The healthy host count dropped to zero shortly after a pipeline run, and the app was genuinely returning 502. The pipeline had reported success.
The deploy step stops and removes the container, then relies on restarting cloud-init to bring a new one up. That is not a deployment strategy, and it does not check whether the new container actually started.
I recovered by re-running the instance boot process. The weakness itself is still there and is documented in the README.
The right fix is a platform that does rolling deployments with health checks, so the new container has to prove itself healthy before the old one goes away. ECS does this natively. Patching the command would shrink the gap but not close it.
Takeaway: a green pipeline is not evidence that the deployment worked. Monitoring caught this, the pipeline did not.
________________________________________
10. A dashboard showing zero is not the same as measuring zero
The healthy host count read zero on the dashboard while the app was clearly serving requests.
I checked with aws elbv2 describe-target-health and the target was reported healthy the entire time, with an instance ID matching the running server. So the metric was wrong, not the infrastructure.
Load balancer metrics are only published while traffic is flowing. During quiet periods there is simply no data, and the dashboard draws that gap as zero rather than as missing.
Nothing needed fixing. It is also why I set the 5xx alarm to treat missing data as not breaching, since otherwise it would trip every quiet period.
Takeaway: check a suspicious metric against the source before acting on it. Knowing how a metric is produced matters as much as reading its value.
________________________________________
11. GitHub authentication
A few smaller blockers pushing the first commit. Password authentication was rejected, since GitHub removed it for Git operations. Then a 403 because my token was missing the repo scope. Then a rejected push because the remote had a LICENSE commit my local repository did not.
I generated a token with repo and workflow scopes, the second being separately required to push anything under .github/workflows/, and merged the two histories with git pull --allow-unrelated-histories.
Takeaway: the workflow scope requirement is easy to miss and gives a confusing error.

