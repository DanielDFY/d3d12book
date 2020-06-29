struct InputData {
	float3 v;
};

StructuredBuffer<InputData> gInput : register(t0);

struct OutputData {
	float length;
};

RWStructuredBuffer<OutputData> gOutput : register(u0);

[numthreads(64, 1, 1)]
void CS(int3 dtid : SV_DispatchThreadID)
{
	gOutput[dtid.x].length = length(gInput[dtid.x].v);
}
