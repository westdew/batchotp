# batchotp

Batch Request OTP from R

This package contains tools for interfacing with an OpenTripPlanner (OTP) server from R. The main tool sends a batch request (templated python script) to the OTP server REST path /otp/scripting/run and fetches the data returned. Other tools support the parameterization of this script, e.g., creating a grid of points, and support the setup of the OTP server, e.g. loading a router.
