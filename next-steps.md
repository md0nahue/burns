OK, my goal for this application

User will upload a spoken dialogue - a rant where they review something or whatever

Then, we need to run a whisper workload on that. I know that the one uh, grok AI, is like 4 cents per hour, so I guess that one is fine to use for doing whisper, especially if it's higher fidelity

I could try to do my own whisper workload that is self-hosted - but that is just an idle fantasy.

Then, I need an LLM command which will take the whisper transcript and then determine which images to pull, and what the time range should be for each image

Then, we pass those commands to our image service bus that we have already, and pull the images as required.

Then, at that point, we need something that will send all of these images to AWS lambda so taht they can get turned into vdieos iwth ken burns and of course written to an s3 bucket

Finally, we need a lambda command that will take all of the images, splice them together, add the original audio, and then allow us to download the completed video.

I think that probably, only the completed video is useful to me - so, we should put a lifeycle policy on the bucket to clear out the old stuff after like 2 weeks or something.

I should see if I still have free tier on insanely fast whisper

So I guess the first step is to get a spoken dialogue about something that I can use as kind of proof of concept.

I guess Groq accepts the file upload directly so that's not too bad.