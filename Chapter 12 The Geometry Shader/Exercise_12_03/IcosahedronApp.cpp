//***************************************************************************************
// Exercise_12_03 IcosahedronApp.cpp by DanielDFY.
//***************************************************************************************

#include "../../Common/d3dApp.h"
#include "../../Common/MathHelper.h"
#include "../../Common/UploadBuffer.h"
#include "../../Common/GeometryGenerator.h"
#include "FrameResource.h"

using Microsoft::WRL::ComPtr;
using namespace DirectX;
using namespace DirectX::PackedVector;

#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "D3D12.lib")

const int gNumFrameResources = 3;

struct RenderItem {
	RenderItem() = default;
	~RenderItem() = default;

	// World matrix of the shape that describes the object's local space
	// relative to the world space, which defines the position, orientation,
	// and scale of the object in the world.
	XMFLOAT4X4 World = MathHelper::Identity4x4();

	// Dirty flag indicating the object data has changed and we need to update the constant buffer.
	// Because we have an object cbuffer for each FrameResource, we have to apply the
	// update to each FrameResource.  Thus, when we modify obect data we should set 
	// NumFramesDirty = gNumFrameResources so that each frame resource gets the update.
	int NumFramesDirty = gNumFrameResources;

	// Index into GPU constant buffer corresponding to the ObjectCB for this render item.
	UINT ObjCBIndex = -1;

	MeshGeometry* Geo = nullptr;
	
	// Primitive topology.
	D3D12_PRIMITIVE_TOPOLOGY PrimitiveType = D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST;

	// DrawIndexedInstanced parameters.
	UINT IndexCount = 0;
	UINT StartIndexLocation = 0;
	UINT BaseVertexLocation = 0;
};

class IcosahedronApp : public D3DApp {
public:
	IcosahedronApp(HINSTANCE hInstance);
	IcosahedronApp(const IcosahedronApp& rhs) = delete;
	IcosahedronApp& operator=(const IcosahedronApp& rhs) = delete;
	~IcosahedronApp();

	bool Initialize() override;

private:
	void OnResize() override;
	void Update(const GameTimer& gt) override;
	void Draw(const GameTimer& gt) override;

	void OnMouseDown(WPARAM btnState, int x, int y) override;
	void OnMouseUp(WPARAM btnState, int x, int y) override;
	void OnMouseMove(WPARAM btnState, int x, int y) override;

	void UpdateCamera(const GameTimer& gt);
	void UpdateObjectCBs(const GameTimer& gt);
	void UpdateMainPassCB(const GameTimer& gt);

	void BuildRootSignature();
	void BuildShadersAndInputLayouts();
	void BuildIcosahedronGeometry();
	void BuildRenderItem();
	void BuildFrameResources();
	void BuildPSO();

private:
	std::vector<std::unique_ptr<FrameResource>> mFrameResources;
	FrameResource* mCurrFrameResource = nullptr;
	int mCurrFrameResourceIndex = 0;

	ComPtr<ID3D12RootSignature> mRootSignature = nullptr;

	std::unique_ptr<MeshGeometry> mIcosahedronGeometry = nullptr;
	std::unordered_map<std::string, ComPtr<ID3DBlob>> mShaders;
	ComPtr<ID3D12PipelineState> mPSO;

	std::vector<D3D12_INPUT_ELEMENT_DESC> mInputLayout;

	std::unique_ptr<RenderItem> mIcosahedronRenderItem = nullptr;

	PassConstants mMainPassCB;

	XMFLOAT3 mEyePos = { 0.0f, 0.0f, 0.0f };
	XMFLOAT4X4 mView = MathHelper::Identity4x4();
	XMFLOAT4X4 mProj = MathHelper::Identity4x4();

	float mTheta = 1.5f * XM_PI;
	float mPhi = XM_PIDIV2 - 0.1f;
	float mRadius = 50.0f;

	POINT mLastMousePos;
};

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPSTR lpCmdLine, _In_ int nShowCmd) {
	#if defined(DEBUG) | defined(_DEBUG)
	_CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);
	#endif

	try {
		IcosahedronApp theApp(hInstance);
		if (!theApp.Initialize())
			return 0;

		return theApp.Run();
	}
	catch (DxException& e) {
		MessageBox(nullptr, e.ToString().c_str(), L"HR Failed", MB_OK);
		return 0;
	}
}

IcosahedronApp::IcosahedronApp(HINSTANCE hInstance)
: D3DApp(hInstance) { }

IcosahedronApp::~IcosahedronApp() {
	if (md3dDevice != nullptr)
		FlushCommandQueue();
}

bool IcosahedronApp::Initialize() {
	if (!D3DApp::Initialize())
		return false;

	// Reset the command list to prep for initialization commands.
	ThrowIfFailed(mCommandList->Reset(mDirectCmdListAlloc.Get(), nullptr));

	BuildRootSignature();
	BuildShadersAndInputLayouts();
	BuildIcosahedronGeometry();
	BuildRenderItem();
	BuildFrameResources();
	BuildPSO();

	// Execute the initialization commands.
	ThrowIfFailed(mCommandList->Close());
	ID3D12CommandList* cmdsLists[] = { mCommandList.Get() };
	mCommandQueue->ExecuteCommandLists(_countof(cmdsLists), cmdsLists);

	// Wait until initialization is complete.
	FlushCommandQueue();

	return true;
}

void IcosahedronApp::OnResize() {
	D3DApp::OnResize();

	// The window resized, so update the aspect ratio and recompute the projection matrix.
	XMMATRIX P = XMMatrixPerspectiveFovLH(0.25f * MathHelper::Pi, AspectRatio(), 1.0f, 1000.0f);
	XMStoreFloat4x4(&mProj, P);
}

void IcosahedronApp::Update(const GameTimer& gt) {
	UpdateCamera(gt);

	// Cycle through the circular frame resource array.
	mCurrFrameResourceIndex = (mCurrFrameResourceIndex + 1) % gNumFrameResources;
	mCurrFrameResource = mFrameResources[mCurrFrameResourceIndex].get();

	// Has the GPU finished processing the commands of the current frame resource?
	// If not, wait until the GPU has completed commands up to this fence point.
	if (mCurrFrameResource->Fence != 0 && mFence->GetCompletedValue() < mCurrFrameResource->Fence) {
		HANDLE eventHandle = CreateEventEx(nullptr, false, false, EVENT_ALL_ACCESS);
		ThrowIfFailed(mFence->SetEventOnCompletion(mCurrFrameResource->Fence, eventHandle));
		WaitForSingleObject(eventHandle, INFINITE);
		CloseHandle(eventHandle);
	}

	UpdateObjectCBs(gt);
	UpdateMainPassCB(gt);
}

void IcosahedronApp::Draw(const GameTimer& gt) {
	auto cmdListAlloc = mCurrFrameResource->CmdListAlloc;

	// Reuse the memory associated with command recording.
	// We can only reset when the associated command lists have finished execution on the GPU.
	ThrowIfFailed(cmdListAlloc->Reset());

	// A command list can be reset after it has been added to the command queue via ExecuteCommandList.
	// Reusing the command list reuses memory.
	ThrowIfFailed(mCommandList->Reset(cmdListAlloc.Get(), mPSO.Get()));

	mCommandList->RSSetViewports(1, &mScreenViewport);
	mCommandList->RSSetScissorRects(1, &mScissorRect);

	// Indicate a state transition on the resource usage.
	mCommandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(CurrentBackBuffer(),
		D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET));

	mCommandList->ClearRenderTargetView(CurrentBackBufferView(), reinterpret_cast<float*>(&mMainPassCB.FogColor), 0, nullptr);
	mCommandList->ClearDepthStencilView(DepthStencilView(), D3D12_CLEAR_FLAG_DEPTH | D3D12_CLEAR_FLAG_STENCIL, 1.0f, 0, 0, nullptr);

	// Specify the buffers we are going to render to.
	mCommandList->OMSetRenderTargets(1, &CurrentBackBufferView(), true, &DepthStencilView());

	mCommandList->SetGraphicsRootSignature(mRootSignature.Get());

	mCommandList->SetGraphicsRootConstantBufferView(0, mCurrFrameResource->ObjectCB->Resource()->GetGPUVirtualAddress());
	mCommandList->SetGraphicsRootConstantBufferView(1, mCurrFrameResource->PassCB->Resource()->GetGPUVirtualAddress());

	mCommandList->IASetVertexBuffers(0, 1, &mIcosahedronRenderItem->Geo->VertexBufferView());
	mCommandList->IASetIndexBuffer(&mIcosahedronRenderItem->Geo->IndexBufferView());
	mCommandList->IASetPrimitiveTopology(mIcosahedronRenderItem->PrimitiveType);

	mCommandList->DrawIndexedInstanced(mIcosahedronRenderItem->IndexCount, 1,
		mIcosahedronRenderItem->StartIndexLocation, mIcosahedronRenderItem->BaseVertexLocation, 0);

	// Indicate a state transition on the resource usage.
	mCommandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(CurrentBackBuffer(),
		D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_PRESENT));

	// Done recording commands.
	ThrowIfFailed(mCommandList->Close());

	// Add the command list to the queue for execution.
	ID3D12CommandList* cmdsLists[] = { mCommandList.Get() };
	mCommandQueue->ExecuteCommandLists(_countof(cmdsLists), cmdsLists);

	// Swap the back and front buffers
	ThrowIfFailed(mSwapChain->Present(0, 0));
	mCurrBackBuffer = (mCurrBackBuffer + 1) % SwapChainBufferCount;

	// Advance the fence value to mark commands up to this fence point.
	mCurrFrameResource->Fence = ++mCurrentFence;

	// Add an instruction to the command queue to set a new fence point. 
	// Because we are on the GPU timeline, the new fence point won't be 
	// set until the GPU finishes processing all the commands prior to this Signal().
	mCommandQueue->Signal(mFence.Get(), mCurrentFence);
}

void IcosahedronApp::OnMouseDown(WPARAM btnState, int x, int y) {
	mLastMousePos.x = x;
	mLastMousePos.y = y;

	SetCapture(mhMainWnd);
}

void IcosahedronApp::OnMouseUp(WPARAM btnState, int x, int y) {
	ReleaseCapture();
}

void IcosahedronApp::OnMouseMove(WPARAM btnState, int x, int y) {
	if ((btnState & MK_LBUTTON) != 0) {
		// Make each pixel correspond to a quarter of a degree.
		const float dx = XMConvertToRadians(0.25f * static_cast<float>(x - mLastMousePos.x));
		const float dy = XMConvertToRadians(0.25f * static_cast<float>(y - mLastMousePos.y));

		// Update angles based on input to orbit camera around box.
		mTheta += dx;
		mPhi += dy;

		// Restrict the angle mPhi.
		mPhi = MathHelper::Clamp(mPhi, 0.1f, MathHelper::Pi - 0.1f);
	}
	else if ((btnState & MK_RBUTTON) != 0) {
		// Make each pixel correspond to 0.2 unit in the scene.
		float dx = 0.2f * static_cast<float>(x - mLastMousePos.x);
		float dy = 0.2f * static_cast<float>(y - mLastMousePos.y);

		// Update the camera radius based on input.
		mRadius += dx - dy;

		// Restrict the radius.
		mRadius = MathHelper::Clamp(mRadius, 5.0f, 150.0f);
	}

	mLastMousePos.x = x;
	mLastMousePos.y = y;
}

void IcosahedronApp::UpdateCamera(const GameTimer& gt) {
	// Convert Spherical to Cartesian coordinates.
	mEyePos.x = mRadius * sinf(mPhi) * cosf(mTheta);
	mEyePos.z = mRadius * sinf(mPhi) * sinf(mTheta);
	mEyePos.y = mRadius * cosf(mPhi);

	// Build the view matrix.
	const XMVECTOR pos = XMVectorSet(mEyePos.x, mEyePos.y, mEyePos.z, 1.0f);
	const XMVECTOR target = XMVectorZero();
	const XMVECTOR up = XMVectorSet(0.0f, 1.0f, 0.0f, 0.0f);

	const XMMATRIX view = XMMatrixLookAtLH(pos, target, up);
	XMStoreFloat4x4(&mView, view);
}

void IcosahedronApp::UpdateObjectCBs(const GameTimer& gt) {
	auto currObjectCB = mCurrFrameResource->ObjectCB.get();
		
	// Only update the cbuffer data if the constants have changed.  
		// This needs to be tracked per frame resource.
	if (mIcosahedronRenderItem->NumFramesDirty > 0) {
		XMMATRIX world = XMLoadFloat4x4(&mIcosahedronRenderItem->World);

		ObjectConstants objConstants;
		XMStoreFloat4x4(&objConstants.World, XMMatrixTranspose(world));

		currObjectCB->CopyData(mIcosahedronRenderItem->ObjCBIndex, objConstants);

		// Next FrameResource need to be updated too.
		mIcosahedronRenderItem->NumFramesDirty--;
	}
}

void IcosahedronApp::UpdateMainPassCB(const GameTimer& gt) {
	const XMMATRIX view = XMLoadFloat4x4(&mView);
	const XMMATRIX proj = XMLoadFloat4x4(&mProj);

	const XMMATRIX viewProj = XMMatrixMultiply(view, proj);
	const XMMATRIX invView = XMMatrixInverse(&XMMatrixDeterminant(view), view);
	const XMMATRIX invProj = XMMatrixInverse(&XMMatrixDeterminant(proj), proj);
	const XMMATRIX invViewProj = XMMatrixInverse(&XMMatrixDeterminant(viewProj), viewProj);

	XMStoreFloat4x4(&mMainPassCB.View, XMMatrixTranspose(view));
	XMStoreFloat4x4(&mMainPassCB.InvView, XMMatrixTranspose(invView));
	XMStoreFloat4x4(&mMainPassCB.Proj, XMMatrixTranspose(proj));
	XMStoreFloat4x4(&mMainPassCB.InvProj, XMMatrixTranspose(invProj));
	XMStoreFloat4x4(&mMainPassCB.ViewProj, XMMatrixTranspose(viewProj));
	XMStoreFloat4x4(&mMainPassCB.InvViewProj, XMMatrixTranspose(invViewProj));
	mMainPassCB.EyePosW = mEyePos;
	mMainPassCB.RenderTargetSize = XMFLOAT2((float)mClientWidth, (float)mClientHeight);
	mMainPassCB.InvRenderTargetSize = XMFLOAT2(1.0f / mClientWidth, 1.0f / mClientHeight);
	mMainPassCB.NearZ = 1.0f;
	mMainPassCB.FarZ = 1000.0f;
	mMainPassCB.TotalTime = gt.TotalTime();
	mMainPassCB.DeltaTime = gt.DeltaTime();
	mMainPassCB.AmbientLight = { 0.25f, 0.25f, 0.35f, 1.0f };
	mMainPassCB.Lights[0].Direction = { 0.57735f, -0.57735f, 0.57735f };
	mMainPassCB.Lights[0].Strength = { 0.6f, 0.6f, 0.6f };
	mMainPassCB.Lights[1].Direction = { -0.57735f, -0.57735f, 0.57735f };
	mMainPassCB.Lights[1].Strength = { 0.3f, 0.3f, 0.3f };
	mMainPassCB.Lights[2].Direction = { 0.0f, -0.707f, -0.707f };
	mMainPassCB.Lights[2].Strength = { 0.15f, 0.15f, 0.15f };

	auto currPassCB = mCurrFrameResource->PassCB.get();
	currPassCB->CopyData(0, mMainPassCB);
}

void IcosahedronApp::BuildRootSignature() {
	// Root parameter can be a table, root descriptor or root constants.
	CD3DX12_ROOT_PARAMETER slotRootParameter[2];

	// Perfomance TIP: Order from most frequent to least frequent.
	slotRootParameter[0].InitAsConstantBufferView(0);
	slotRootParameter[1].InitAsConstantBufferView(1);

	// A root signature is an array of root parameters.
	CD3DX12_ROOT_SIGNATURE_DESC rootSigDesc(2, slotRootParameter,
		0, nullptr,
		D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

	// create a root signature with a single slot which points to a descriptor range consisting of a single constant buffer
	ComPtr<ID3DBlob> serializedRootSig = nullptr;
	ComPtr<ID3DBlob> errorBlob = nullptr;
	HRESULT hr = D3D12SerializeRootSignature(&rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1,
		serializedRootSig.GetAddressOf(), errorBlob.GetAddressOf());

	if (errorBlob != nullptr) {
		::OutputDebugStringA(static_cast<char*>(errorBlob->GetBufferPointer()));
	}
	ThrowIfFailed(hr);

	ThrowIfFailed(md3dDevice->CreateRootSignature(
		0,
		serializedRootSig->GetBufferPointer(),
		serializedRootSig->GetBufferSize(),
		IID_PPV_ARGS(mRootSignature.GetAddressOf())));
}

void IcosahedronApp::BuildShadersAndInputLayouts() {
	mShaders["VS"] = d3dUtil::CompileShader(L"Shaders/Default.hlsl", nullptr, "VS", "vs_5_1");
	mShaders["GS"] = d3dUtil::CompileShader(L"Shaders/Default.hlsl", nullptr, "GS", "gs_5_1");
	mShaders["PS"] = d3dUtil::CompileShader(L"Shaders/Default.hlsl", nullptr, "PS", "ps_5_1");

	mInputLayout =
	{
		{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
		{ "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
	};
}

void IcosahedronApp::BuildIcosahedronGeometry() {
	constexpr int subdivisionCount = 2;
	constexpr float radius = 5.0f;

	GeometryGenerator geometryGenerator;
	GeometryGenerator::MeshData icosahedron = geometryGenerator.CreateGeosphere(radius, subdivisionCount);

	std::vector<Vertex> vertices(icosahedron.Vertices.size());
	
	for (int i = 0; i < icosahedron.Vertices.size(); ++i) {
		vertices[i].Pos = icosahedron.Vertices[i].Position;
		vertices[i].Color = XMFLOAT4(Colors::Black);
	}

	std::vector<std::uint16_t> indices = icosahedron.GetIndices16();

	const UINT vertexBufferByteSize = static_cast<UINT>(vertices.size()) * sizeof(Vertex);
	const UINT indexBufferByteSize = static_cast<UINT>(indices.size()) * sizeof(std::uint16_t);

	mIcosahedronGeometry = std::make_unique<MeshGeometry>();
	mIcosahedronGeometry->Name = "icosahedronGeo";

	ThrowIfFailed(D3DCreateBlob(vertexBufferByteSize, mIcosahedronGeometry->VertexBufferCPU.GetAddressOf()));
	CopyMemory(mIcosahedronGeometry->VertexBufferCPU->GetBufferPointer(), vertices.data(), vertexBufferByteSize);

	ThrowIfFailed(D3DCreateBlob(indexBufferByteSize, mIcosahedronGeometry->IndexBufferCPU.GetAddressOf()));
	CopyMemory(mIcosahedronGeometry->IndexBufferCPU->GetBufferPointer(), indices.data(), indexBufferByteSize);

	mIcosahedronGeometry->VertexBufferGPU = d3dUtil::CreateDefaultBuffer(md3dDevice.Get(), mCommandList.Get(),
		vertices.data(), vertexBufferByteSize, mIcosahedronGeometry->VertexBufferUploader);

	mIcosahedronGeometry->IndexBufferGPU = d3dUtil::CreateDefaultBuffer(md3dDevice.Get(), mCommandList.Get(),
		indices.data(), indexBufferByteSize, mIcosahedronGeometry->IndexBufferUploader);

	mIcosahedronGeometry->VertexByteStride = sizeof(Vertex);
	mIcosahedronGeometry->VertexBufferByteSize = vertexBufferByteSize;
	mIcosahedronGeometry->IndexFormat = DXGI_FORMAT_R16_UINT;
	mIcosahedronGeometry->IndexBufferByteSize = indexBufferByteSize;

	SubmeshGeometry submeshGeometry;
	submeshGeometry.IndexCount = static_cast<UINT>(indices.size());
	submeshGeometry.StartIndexLocation = 0;
	submeshGeometry.BaseVertexLocation = 0;

	mIcosahedronGeometry->DrawArgs["icosahedron"] = submeshGeometry;
}

void IcosahedronApp::BuildRenderItem() {
	mIcosahedronRenderItem = std::make_unique<RenderItem>();
	mIcosahedronRenderItem->World = MathHelper::Identity4x4();
	mIcosahedronRenderItem->ObjCBIndex = 0;
	mIcosahedronRenderItem->Geo = mIcosahedronGeometry.get();
	mIcosahedronRenderItem->PrimitiveType = D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST;
	mIcosahedronRenderItem->IndexCount = mIcosahedronRenderItem->Geo->DrawArgs["icosahedron"].IndexCount;
	mIcosahedronRenderItem->StartIndexLocation = mIcosahedronRenderItem->Geo->DrawArgs["icosahedron"].StartIndexLocation;
	mIcosahedronRenderItem->BaseVertexLocation = mIcosahedronRenderItem->Geo->DrawArgs["icosahedron"].BaseVertexLocation;
}

void IcosahedronApp::BuildFrameResources() {
	for (int i = 0; i < gNumFrameResources; ++i) {
		mFrameResources.push_back(std::make_unique<FrameResource>(md3dDevice.Get(), 1, 1));
	}
}

void IcosahedronApp::BuildPSO() {
	D3D12_GRAPHICS_PIPELINE_STATE_DESC opaqueLinePsoDesc;
	ZeroMemory(&opaqueLinePsoDesc, sizeof(D3D12_GRAPHICS_PIPELINE_STATE_DESC));
	opaqueLinePsoDesc.InputLayout = { mInputLayout.data(), static_cast<UINT>(mInputLayout.size()) };
	opaqueLinePsoDesc.pRootSignature = mRootSignature.Get();
	opaqueLinePsoDesc.VS =
	{
		reinterpret_cast<BYTE*>(mShaders["VS"]->GetBufferPointer()),
		mShaders["VS"]->GetBufferSize()
	};
	opaqueLinePsoDesc.GS =
	{
		reinterpret_cast<BYTE*>(mShaders["GS"]->GetBufferPointer()),
		mShaders["GS"]->GetBufferSize()
	};
	opaqueLinePsoDesc.PS =
	{
		reinterpret_cast<BYTE*>(mShaders["PS"]->GetBufferPointer()),
		mShaders["PS"]->GetBufferSize()
	};
	opaqueLinePsoDesc.RasterizerState = CD3DX12_RASTERIZER_DESC(D3D12_DEFAULT);
	opaqueLinePsoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_WIREFRAME;
	opaqueLinePsoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
	opaqueLinePsoDesc.BlendState = CD3DX12_BLEND_DESC(D3D12_DEFAULT);
	opaqueLinePsoDesc.DepthStencilState = CD3DX12_DEPTH_STENCIL_DESC(D3D12_DEFAULT);
	opaqueLinePsoDesc.SampleMask = UINT_MAX;
	opaqueLinePsoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
	opaqueLinePsoDesc.NumRenderTargets = 1;
	opaqueLinePsoDesc.RTVFormats[0] = mBackBufferFormat;
	opaqueLinePsoDesc.SampleDesc.Count = 1;
	opaqueLinePsoDesc.SampleDesc.Quality = 0;
	opaqueLinePsoDesc.DSVFormat = mDepthStencilFormat;
	ThrowIfFailed(md3dDevice->CreateGraphicsPipelineState(&opaqueLinePsoDesc,
		IID_PPV_ARGS(mPSO.GetAddressOf())));
}