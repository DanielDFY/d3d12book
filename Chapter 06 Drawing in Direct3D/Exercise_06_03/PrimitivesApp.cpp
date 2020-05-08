//***************************************************************************************
// Exercise_06_03 PrimitivesApp.cpp by DanielDFY.
//
// Draw vertices specified by different primitive topologies
//
// Controls:
//   Hold the left mouse button down and move the mouse to rotate.
//   Hold the right mouse button down and move the mouse to zoom in and out.
//***************************************************************************************

#include "../../Common/d3dApp.h"
#include "../../Common/MathHelper.h"
#include "../../Common/UploadBuffer.h"

using Microsoft::WRL::ComPtr;
using namespace DirectX;
using namespace DirectX::PackedVector;

struct Vertex {
    XMFLOAT3 Pos;
    XMFLOAT4 Color;
};

struct ObjectConstants {
    XMFLOAT4X4 WorldViewProj = MathHelper::Identity4x4();
};

class PrimitivesApp : public D3DApp {
public:
    PrimitivesApp(HINSTANCE hInstance);
    PrimitivesApp(const PrimitivesApp& rhs) = delete;
    PrimitivesApp& operator=(const PrimitivesApp& rhs) = delete;
    ~PrimitivesApp();

    virtual bool Initialize()override;

private:
    virtual void OnResize()override;
    virtual void Update(const GameTimer& gt)override;
    virtual void Draw(const GameTimer& gt)override;

    virtual void OnMouseDown(WPARAM btnState, int x, int y)override;
    virtual void OnMouseUp(WPARAM btnState, int x, int y)override;
    virtual void OnMouseMove(WPARAM btnState, int x, int y)override;

    void BuildDescriptorHeaps();
    void BuildConstantBuffers();
    void BuildRootSignature();
    void BuildShadersAndInputLayout();
    void BuildPrimitivesGeometry();
    void BuildPSOs();

private:

    ComPtr<ID3D12RootSignature> mRootSignature = nullptr;
    ComPtr<ID3D12DescriptorHeap> mCbvHeap = nullptr;

    std::unique_ptr<UploadBuffer<ObjectConstants>> mObjectCB = nullptr;

    std::unique_ptr<MeshGeometry> mPrimitivesGeo = nullptr;

    ComPtr<ID3DBlob> mvsByteCode = nullptr;
    ComPtr<ID3DBlob> mpsByteCode = nullptr;

    std::vector<D3D12_INPUT_ELEMENT_DESC> mInputLayout;

    std::unordered_map<std::string, ComPtr<ID3D12PipelineState>> mPSOs;

    XMFLOAT4X4 mWorld = MathHelper::Identity4x4();
    XMFLOAT4X4 mView = MathHelper::Identity4x4();
    XMFLOAT4X4 mProj = MathHelper::Identity4x4();

    float mTheta = 1.5f * XM_PI;
    float mPhi = XM_PIDIV4;
    float mRadius = 5.0f;

    POINT mLastMousePos;
};

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE prevInstance,
    PSTR cmdLine, int showCmd) {
    // Enable run-time memory check for debug builds.
#if defined(DEBUG) | defined(_DEBUG)
    _CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);
#endif

    try {
        PrimitivesApp theApp(hInstance);
        if (!theApp.Initialize())
            return 0;

        return theApp.Run();
    }
    catch (DxException& e) {
        MessageBox(nullptr, e.ToString().c_str(), L"HR Failed", MB_OK);
        return 0;
    }
}

PrimitivesApp::PrimitivesApp(HINSTANCE hInstance)
    : D3DApp(hInstance) {
}

PrimitivesApp::~PrimitivesApp() {
}

bool PrimitivesApp::Initialize() {
    if (!D3DApp::Initialize())
        return false;

    // Reset the command list to prep for initialization commands.
    ThrowIfFailed(mCommandList->Reset(mDirectCmdListAlloc.Get(), nullptr));

    BuildDescriptorHeaps();
    BuildConstantBuffers();
    BuildRootSignature();
    BuildShadersAndInputLayout();
    BuildPrimitivesGeometry();
    BuildPSOs();

    // Execute the initialization commands.
    ThrowIfFailed(mCommandList->Close());
    ID3D12CommandList* cmdsLists[] = { mCommandList.Get() };
    mCommandQueue->ExecuteCommandLists(_countof(cmdsLists), cmdsLists);

    // Wait until initialization is complete.
    FlushCommandQueue();

    return true;
}

void PrimitivesApp::OnResize() {
    D3DApp::OnResize();

    // The window resized, so update the aspect ratio and recompute the projection matrix.
    XMMATRIX P = XMMatrixPerspectiveFovLH(0.25f * MathHelper::Pi, AspectRatio(), 1.0f, 1000.0f);
    XMStoreFloat4x4(&mProj, P);
}

void PrimitivesApp::Update(const GameTimer& gt) {
    // Convert Spherical to Cartesian coordinates.
    float x = mRadius * sinf(mPhi) * cosf(mTheta);
    float z = mRadius * sinf(mPhi) * sinf(mTheta);
    float y = mRadius * cosf(mPhi);

    // Build the view matrix.
    XMVECTOR pos = XMVectorSet(x, y, z, 1.0f);
    XMVECTOR target = XMVectorZero();
    XMVECTOR up = XMVectorSet(0.0f, 1.0f, 0.0f, 0.0f);

    XMMATRIX view = XMMatrixLookAtLH(pos, target, up);
    XMStoreFloat4x4(&mView, view);

    XMMATRIX world = XMLoadFloat4x4(&mWorld);
    XMMATRIX proj = XMLoadFloat4x4(&mProj);
    XMMATRIX worldViewProj = world * view * proj;

    // Update the constant buffer with the latest worldViewProj matrix.
    ObjectConstants objConstants;
    XMStoreFloat4x4(&objConstants.WorldViewProj, XMMatrixTranspose(worldViewProj));
    mObjectCB->CopyData(0, objConstants);
}

void PrimitivesApp::Draw(const GameTimer& gt) {
    // Reuse the memory associated with command recording.
    // We can only reset when the associated command lists have finished execution on the GPU.
    ThrowIfFailed(mDirectCmdListAlloc->Reset());

    // A command list can be reset after it has been added to the command queue via ExecuteCommandList.
    // Reusing the command list reuses memory.
    ThrowIfFailed(mCommandList->Reset(mDirectCmdListAlloc.Get(), mPSOs["point"].Get()));

    mCommandList->RSSetViewports(1, &mScreenViewport);
    mCommandList->RSSetScissorRects(1, &mScissorRect);

    // Indicate a state transition on the resource usage.
    mCommandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(CurrentBackBuffer(),
        D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET));

    // Clear the back buffer and depth buffer.
    mCommandList->ClearRenderTargetView(CurrentBackBufferView(), Colors::LightSteelBlue, 0, nullptr);
    mCommandList->ClearDepthStencilView(DepthStencilView(), D3D12_CLEAR_FLAG_DEPTH | D3D12_CLEAR_FLAG_STENCIL, 1.0f, 0, 0, nullptr);

    // Specify the buffers we are going to render to.
    mCommandList->OMSetRenderTargets(1, &CurrentBackBufferView(), true, &DepthStencilView());

    ID3D12DescriptorHeap* descriptorHeaps[] = { mCbvHeap.Get() };
    mCommandList->SetDescriptorHeaps(_countof(descriptorHeaps), descriptorHeaps);

    mCommandList->SetGraphicsRootSignature(mRootSignature.Get());

    mCommandList->SetGraphicsRootDescriptorTable(0, mCbvHeap->GetGPUDescriptorHandleForHeapStart());

	// Draw point list
    mCommandList->IASetVertexBuffers(0, 1, &mPrimitivesGeo->VertexBufferView());
    mCommandList->IASetIndexBuffer(&mPrimitivesGeo->IndexBufferView());
    mCommandList->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_POINTLIST);

    mCommandList->DrawIndexedInstanced(
        mPrimitivesGeo->DrawArgs["pointList"].IndexCount,
        1, 
        mPrimitivesGeo->DrawArgs["pointList"].StartIndexLocation, 
        mPrimitivesGeo->DrawArgs["pointList"].BaseVertexLocation, 
        0);

    // Draw line strip
    mCommandList->SetPipelineState(mPSOs["line"].Get());
    mCommandList->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_LINESTRIP);

    mCommandList->DrawIndexedInstanced(
        mPrimitivesGeo->DrawArgs["lineStrip"].IndexCount,
        1,
        mPrimitivesGeo->DrawArgs["lineStrip"].StartIndexLocation,
        mPrimitivesGeo->DrawArgs["lineStrip"].BaseVertexLocation,
        0);

    // Draw line list
    mCommandList->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_LINELIST);

    mCommandList->DrawIndexedInstanced(
        mPrimitivesGeo->DrawArgs["lineList"].IndexCount,
        1,
        mPrimitivesGeo->DrawArgs["lineList"].StartIndexLocation,
        mPrimitivesGeo->DrawArgs["lineList"].BaseVertexLocation,
        0);

    // Draw triangle strip
    mCommandList->SetPipelineState(mPSOs["triangle"].Get());
    mCommandList->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP);

    mCommandList->DrawIndexedInstanced(
        mPrimitivesGeo->DrawArgs["triangleStrip"].IndexCount,
        1,
        mPrimitivesGeo->DrawArgs["triangleStrip"].StartIndexLocation,
        mPrimitivesGeo->DrawArgs["triangleStrip"].BaseVertexLocation,
        0);

    // Draw triangle list
    mCommandList->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    mCommandList->DrawIndexedInstanced(
        mPrimitivesGeo->DrawArgs["triangleList"].IndexCount,
        1,
        mPrimitivesGeo->DrawArgs["triangleList"].StartIndexLocation,
        mPrimitivesGeo->DrawArgs["triangleList"].BaseVertexLocation,
        0);

    // Indicate a state transition on the resource usage.
    mCommandList->ResourceBarrier(1, &CD3DX12_RESOURCE_BARRIER::Transition(CurrentBackBuffer(),
        D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_PRESENT));

    // Done recording commands.
    ThrowIfFailed(mCommandList->Close());

    // Add the command list to the queue for execution.
    ID3D12CommandList* cmdsLists[] = { mCommandList.Get() };
    mCommandQueue->ExecuteCommandLists(_countof(cmdsLists), cmdsLists);

    // swap the back and front buffers
    ThrowIfFailed(mSwapChain->Present(0, 0));
    mCurrBackBuffer = (mCurrBackBuffer + 1) % SwapChainBufferCount;

    // Wait until frame commands are complete.  This waiting is inefficient and is
    // done for simplicity.  Later we will show how to organize our rendering code
    // so we do not have to wait per frame.
    FlushCommandQueue();
}

void PrimitivesApp::OnMouseDown(WPARAM btnState, int x, int y) {
    mLastMousePos.x = x;
    mLastMousePos.y = y;

    SetCapture(mhMainWnd);
}

void PrimitivesApp::OnMouseUp(WPARAM btnState, int x, int y) {
    ReleaseCapture();
}

void PrimitivesApp::OnMouseMove(WPARAM btnState, int x, int y) {
    if ((btnState & MK_LBUTTON) != 0) {
        // Make each pixel correspond to a quarter of a degree.
        float dx = XMConvertToRadians(0.25f * static_cast<float>(x - mLastMousePos.x));
        float dy = XMConvertToRadians(0.25f * static_cast<float>(y - mLastMousePos.y));

        // Update angles based on input to orbit camera around box.
        mTheta -= dx;
        mPhi -= dy;

        // Restrict the angle mPhi.
        mPhi = MathHelper::Clamp(mPhi, 0.1f, MathHelper::Pi - 0.1f);
    }
    else if ((btnState & MK_RBUTTON) != 0) {
        // Make each pixel correspond to 0.005 unit in the scene.
        float dx = 0.005f * static_cast<float>(x - mLastMousePos.x);
        float dy = 0.005f * static_cast<float>(y - mLastMousePos.y);

        // Update the camera radius based on input.
        mRadius += dx - dy;

        // Restrict the radius.
        mRadius = MathHelper::Clamp(mRadius, 3.0f, 15.0f);
    }

    mLastMousePos.x = x;
    mLastMousePos.y = y;
}

void PrimitivesApp::BuildDescriptorHeaps() {
    D3D12_DESCRIPTOR_HEAP_DESC cbvHeapDesc;
    cbvHeapDesc.NumDescriptors = 1;
    cbvHeapDesc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    cbvHeapDesc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    cbvHeapDesc.NodeMask = 0;
    ThrowIfFailed(md3dDevice->CreateDescriptorHeap(&cbvHeapDesc,
        IID_PPV_ARGS(&mCbvHeap)));
}

void PrimitivesApp::BuildConstantBuffers() {
    mObjectCB = std::make_unique<UploadBuffer<ObjectConstants>>(md3dDevice.Get(), 1, true);

    UINT objCBByteSize = d3dUtil::CalcConstantBufferByteSize(sizeof(ObjectConstants));

    D3D12_GPU_VIRTUAL_ADDRESS cbAddress = mObjectCB->Resource()->GetGPUVirtualAddress();
    // Offset to the ith object constant buffer in the buffer.
    long long boxCBufIndex = 0;
    cbAddress += boxCBufIndex * static_cast<long long>(objCBByteSize);

    D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc;
    cbvDesc.BufferLocation = cbAddress;
    cbvDesc.SizeInBytes = d3dUtil::CalcConstantBufferByteSize(sizeof(ObjectConstants));

    md3dDevice->CreateConstantBufferView(
        &cbvDesc,
        mCbvHeap->GetCPUDescriptorHandleForHeapStart());
}

void PrimitivesApp::BuildRootSignature() {
    // Shader programs typically require resources as input (constant buffers,
    // textures, samplers).  The root signature defines the resources the shader
    // programs expect.  If we think of the shader programs as a function, and
    // the input resources as function parameters, then the root signature can be
    // thought of as defining the function signature.  

    // Root parameter can be a table, root descriptor or root constants.
    CD3DX12_ROOT_PARAMETER slotRootParameter[1];

    // Create a single descriptor table of CBVs.
    CD3DX12_DESCRIPTOR_RANGE cbvTable;
    cbvTable.Init(D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0);
    slotRootParameter[0].InitAsDescriptorTable(1, &cbvTable);

    // A root signature is an array of root parameters.
    CD3DX12_ROOT_SIGNATURE_DESC rootSigDesc(1, slotRootParameter, 0, nullptr,
        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

    // create a root signature with a single slot which points to a descriptor range consisting of a single constant buffer
    ComPtr<ID3DBlob> serializedRootSig = nullptr;
    ComPtr<ID3DBlob> errorBlob = nullptr;
    HRESULT hr = D3D12SerializeRootSignature(&rootSigDesc, D3D_ROOT_SIGNATURE_VERSION_1,
        serializedRootSig.GetAddressOf(), errorBlob.GetAddressOf());

    if (errorBlob != nullptr) {
        ::OutputDebugStringA((char*)errorBlob->GetBufferPointer());
    }
    ThrowIfFailed(hr);

    ThrowIfFailed(md3dDevice->CreateRootSignature(
        0,
        serializedRootSig->GetBufferPointer(),
        serializedRootSig->GetBufferSize(),
        IID_PPV_ARGS(&mRootSignature)));
}

void PrimitivesApp::BuildShadersAndInputLayout() {
    HRESULT hr = S_OK;

    // runtime compilation
    // mvsByteCode = d3dUtil::CompileShader(L"Shaders\\color.hlsl", nullptr, "VS", "vs_5_1");
    // mpsByteCode = d3dUtil::CompileShader(L"Shaders\\color.hlsl", nullptr, "PS", "ps_5_1");

    // offline compilation (use FXC tool to compile HLSL shader)
    mvsByteCode = d3dUtil::LoadBinary(L"Shaders/color_vs.cso");
    mpsByteCode = d3dUtil::LoadBinary(L"Shaders/color_ps.cso");

    mInputLayout =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 }
    };
}

void PrimitivesApp::BuildPrimitivesGeometry() {
    std::array<Vertex, 41> vertices =
    {
    	// point list
        Vertex({ XMFLOAT3(-4.0f, -2.0f, -2.0f), XMFLOAT4(Colors::White) }),
        Vertex({ XMFLOAT3(-3.0f, +1.0f, -2.0f), XMFLOAT4(Colors::Black) }),
        Vertex({ XMFLOAT3(-2.0f, -1.0f, -2.0f), XMFLOAT4(Colors::Red) }),
        Vertex({ XMFLOAT3(+0.0f, +0.5f, -2.0f), XMFLOAT4(Colors::Green) }),
        Vertex({ XMFLOAT3(+0.5f, -0.5f, -2.0f), XMFLOAT4(Colors::Blue) }),
        Vertex({ XMFLOAT3(+1.0f, +0.5f, -2.0f), XMFLOAT4(Colors::Yellow) }),
        Vertex({ XMFLOAT3(+2.0f, -0.2f, -2.0f), XMFLOAT4(Colors::Cyan) }),
        Vertex({ XMFLOAT3(+4.0f, +2.0f, -2.0f), XMFLOAT4(Colors::Magenta) }),

        // line strip
        Vertex({ XMFLOAT3(-4.0f, -2.0f, -1.0f), XMFLOAT4(Colors::White) }),
        Vertex({ XMFLOAT3(-3.0f, +1.0f, -1.0f), XMFLOAT4(Colors::Black) }),
        Vertex({ XMFLOAT3(-2.0f, -1.0f, -1.0f), XMFLOAT4(Colors::Red) }),
        Vertex({ XMFLOAT3(+0.0f, +0.5f, -1.0f), XMFLOAT4(Colors::Green) }),
        Vertex({ XMFLOAT3(+0.5f, -0.5f, -1.0f), XMFLOAT4(Colors::Blue) }),
        Vertex({ XMFLOAT3(+1.0f, +0.5f, -1.0f), XMFLOAT4(Colors::Yellow) }),
        Vertex({ XMFLOAT3(+2.0f, -0.2f, -1.0f), XMFLOAT4(Colors::Cyan) }),
        Vertex({ XMFLOAT3(+4.0f, +2.0f, -1.0f), XMFLOAT4(Colors::Magenta) }),

        // line list
        Vertex({ XMFLOAT3(-4.0f, -2.0f, +0.0f), XMFLOAT4(Colors::White) }),
        Vertex({ XMFLOAT3(-3.0f, +1.0f, +0.0f), XMFLOAT4(Colors::Black) }),
        Vertex({ XMFLOAT3(-2.0f, -1.0f, +0.0f), XMFLOAT4(Colors::Red) }),
        Vertex({ XMFLOAT3(+0.0f, +0.5f, +0.0f), XMFLOAT4(Colors::Green) }),
        Vertex({ XMFLOAT3(+0.5f, -0.5f, +0.0f), XMFLOAT4(Colors::Blue) }),
        Vertex({ XMFLOAT3(+1.0f, +0.5f, +0.0f), XMFLOAT4(Colors::Yellow) }),
        Vertex({ XMFLOAT3(+2.0f, -0.2f, +0.0f), XMFLOAT4(Colors::Cyan) }),
        Vertex({ XMFLOAT3(+4.0f, +2.0f, +0.0f), XMFLOAT4(Colors::Magenta) }),

        // triangle strip
        Vertex({ XMFLOAT3(-4.0f, -2.0f, +1.0f), XMFLOAT4(Colors::White) }),
        Vertex({ XMFLOAT3(-3.0f, +1.0f, +1.0f), XMFLOAT4(Colors::Black) }),
        Vertex({ XMFLOAT3(-2.0f, -1.0f, +1.0f), XMFLOAT4(Colors::Red) }),
        Vertex({ XMFLOAT3(+0.0f, +0.5f, +1.0f), XMFLOAT4(Colors::Green) }),
        Vertex({ XMFLOAT3(+0.5f, -0.5f, +1.0f), XMFLOAT4(Colors::Blue) }),
        Vertex({ XMFLOAT3(+1.0f, +0.5f, +1.0f), XMFLOAT4(Colors::Yellow) }),
        Vertex({ XMFLOAT3(+2.0f, -0.2f, +1.0f), XMFLOAT4(Colors::Cyan) }),
        Vertex({ XMFLOAT3(+4.0f, +2.0f, +1.0f), XMFLOAT4(Colors::Magenta) }),

        // triangle list
        Vertex({ XMFLOAT3(-4.0f, -2.0f, +2.0f), XMFLOAT4(Colors::White) }),
        Vertex({ XMFLOAT3(-3.0f, +1.0f, +2.0f), XMFLOAT4(Colors::Black) }),
        Vertex({ XMFLOAT3(-2.0f, -1.0f, +2.0f), XMFLOAT4(Colors::Red) }),
        Vertex({ XMFLOAT3(+0.0f, +0.5f, +2.0f), XMFLOAT4(Colors::Green) }),
        Vertex({ XMFLOAT3(+0.5f, -0.5f, +2.0f), XMFLOAT4(Colors::Blue) }),
        Vertex({ XMFLOAT3(+1.0f, +0.5f, +2.0f), XMFLOAT4(Colors::Yellow) }),
        Vertex({ XMFLOAT3(+2.0f, -0.2f, +2.0f), XMFLOAT4(Colors::Cyan) }),
        Vertex({ XMFLOAT3(+4.0f, +2.0f, +2.0f), XMFLOAT4(Colors::Magenta) }),
        Vertex({ XMFLOAT3(+4.5f, +1.5f, +2.0f), XMFLOAT4(Colors::White) })
    };

    std::array<std::uint16_t, 41> indices =
    {
        // point list
        0, 1, 2, 3, 4, 5, 6, 7,

        // line strip
        0, 1, 2, 3, 4, 5, 6, 7,

        // line list
        0, 1, 2, 3, 4, 5, 6, 7,

        // triangle strip
        0, 1, 2, 3, 4, 5, 6, 7,

        // triangle list
        0, 1, 2, 3, 5, 4, 6, 7, 8
    };

    const UINT vbByteSize = static_cast<UINT>(vertices.size() * sizeof(Vertex));
    const UINT ibByteSize = static_cast<UINT>(indices.size() * sizeof(std::uint16_t));

    mPrimitivesGeo = std::make_unique<MeshGeometry>();
    mPrimitivesGeo->Name = "primitivesGeo";

    ThrowIfFailed(D3DCreateBlob(vbByteSize, &mPrimitivesGeo->VertexBufferCPU));
    CopyMemory(mPrimitivesGeo->VertexBufferCPU->GetBufferPointer(), vertices.data(), vbByteSize);

    ThrowIfFailed(D3DCreateBlob(ibByteSize, &mPrimitivesGeo->IndexBufferCPU));
    CopyMemory(mPrimitivesGeo->IndexBufferCPU->GetBufferPointer(), indices.data(), ibByteSize);

    mPrimitivesGeo->VertexBufferGPU = d3dUtil::CreateDefaultBuffer(md3dDevice.Get(),
        mCommandList.Get(), vertices.data(), vbByteSize, mPrimitivesGeo->VertexBufferUploader);

    mPrimitivesGeo->IndexBufferGPU = d3dUtil::CreateDefaultBuffer(md3dDevice.Get(),
        mCommandList.Get(), indices.data(), ibByteSize, mPrimitivesGeo->IndexBufferUploader);

    mPrimitivesGeo->VertexByteStride = sizeof(Vertex);
    mPrimitivesGeo->VertexBufferByteSize = vbByteSize;
    mPrimitivesGeo->IndexFormat = DXGI_FORMAT_R16_UINT;
    mPrimitivesGeo->IndexBufferByteSize = ibByteSize;

	// point list
    SubmeshGeometry pointListGeo;
    pointListGeo.IndexCount = 8;
    pointListGeo.StartIndexLocation = 0;
    pointListGeo.BaseVertexLocation = 0;
    mPrimitivesGeo->DrawArgs["pointList"] = pointListGeo;

	// line strip
    SubmeshGeometry lineStripGeo;
    lineStripGeo.IndexCount = 8;
    lineStripGeo.StartIndexLocation = 8;
    lineStripGeo.BaseVertexLocation = 8;
    mPrimitivesGeo->DrawArgs["lineStrip"] = lineStripGeo;

	// line list
    SubmeshGeometry lineListGeo;
    lineListGeo.IndexCount = 8;
    lineListGeo.StartIndexLocation = 16;
    lineListGeo.BaseVertexLocation = 16;
    mPrimitivesGeo->DrawArgs["lineList"] = lineListGeo;

	// triangle strip
    SubmeshGeometry triangleStripGeo;
    triangleStripGeo.IndexCount = 8;
    triangleStripGeo.StartIndexLocation = 24;
    triangleStripGeo.BaseVertexLocation = 24;
    mPrimitivesGeo->DrawArgs["triangleStrip"] = triangleStripGeo;

	// triangle list
    SubmeshGeometry triangleListGeo;
    triangleListGeo.IndexCount = 9;
    triangleListGeo.StartIndexLocation = 32;
    triangleListGeo.BaseVertexLocation = 32;
    mPrimitivesGeo->DrawArgs["triangleList"] = triangleListGeo;
}

void PrimitivesApp::BuildPSOs() {
	// create point PSO
    D3D12_GRAPHICS_PIPELINE_STATE_DESC pointPSODesc;
    ZeroMemory(&pointPSODesc, sizeof(D3D12_GRAPHICS_PIPELINE_STATE_DESC));
    pointPSODesc.InputLayout = { mInputLayout.data(), static_cast<UINT>(mInputLayout.size()) };
    pointPSODesc.pRootSignature = mRootSignature.Get();
    pointPSODesc.VS =
    {
        reinterpret_cast<BYTE*>(mvsByteCode->GetBufferPointer()),
        mvsByteCode->GetBufferSize()
    };
    pointPSODesc.PS =
    {
        reinterpret_cast<BYTE*>(mpsByteCode->GetBufferPointer()),
        mpsByteCode->GetBufferSize()
    };
    pointPSODesc.RasterizerState = CD3DX12_RASTERIZER_DESC(D3D12_DEFAULT);
    pointPSODesc.BlendState = CD3DX12_BLEND_DESC(D3D12_DEFAULT);
    pointPSODesc.DepthStencilState = CD3DX12_DEPTH_STENCIL_DESC(D3D12_DEFAULT);
    pointPSODesc.SampleMask = UINT_MAX;
    pointPSODesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_POINT;
    pointPSODesc.NumRenderTargets = 1;
    pointPSODesc.RTVFormats[0] = mBackBufferFormat;
    pointPSODesc.SampleDesc.Count = m4xMsaaState ? 4 : 1;
    pointPSODesc.SampleDesc.Quality = m4xMsaaState ? (m4xMsaaQuality - 1) : 0;
    pointPSODesc.DSVFormat = mDepthStencilFormat;
    ThrowIfFailed(md3dDevice->CreateGraphicsPipelineState(&pointPSODesc, IID_PPV_ARGS(&mPSOs["point"])));

	// create line PSO
    D3D12_GRAPHICS_PIPELINE_STATE_DESC linePSODesc = pointPSODesc;  // copy
    pointPSODesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE;
    ThrowIfFailed(md3dDevice->CreateGraphicsPipelineState(&linePSODesc, IID_PPV_ARGS(&mPSOs["line"])));

    // create triangle PSO
    D3D12_GRAPHICS_PIPELINE_STATE_DESC trianglePSODesc = pointPSODesc;  // copy
    pointPSODesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    ThrowIfFailed(md3dDevice->CreateGraphicsPipelineState(&trianglePSODesc, IID_PPV_ARGS(&mPSOs["triangle"])));
}