struct InputData {
	float3 v;
};

ConsumeStructuredBuffer<InputData> gInput : register(t0);

struct OutputData {
	float length;
};

AppendStructuredBuffer<OutputData> gOutput : register(u0);


[numthreads(64, 1, 1)]
void CS()
{
	InputData inputData = gInput.Consume();
	OutputData outputData = { length(inputData.v) };
	gOutput.Append(outputData);
}
