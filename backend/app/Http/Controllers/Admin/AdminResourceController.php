<?php

namespace App\Http\Controllers\Admin;

use App\Services\Admin\AdminCrudService;
use App\Services\Admin\AdminPageQueryService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminResourceController
{
    public function __construct(
        private readonly AdminPageQueryService $adminPageQueryService,
        private readonly AdminCrudService $adminCrudService,
    ) {
    }

    public function index(Request $request, string $resource): View
    {
        return view('admin.resources.index', $this->adminPageQueryService->buildIndexPageData($resource, $request));
    }

    public function create(string $resource): View
    {
        return view('admin.resources.form', $this->adminPageQueryService->buildFormPageData($resource));
    }

    public function store(Request $request, string $resource): RedirectResponse
    {
        $this->adminCrudService->store($resource, $request->all());

        return redirect()
            ->route('admin.resources.index', ['resource' => $resource])
            ->with('status', '保存成功');
    }

    public function edit(string $resource, string $record): View
    {
        return view('admin.resources.form', $this->adminPageQueryService->buildFormPageData($resource, $record));
    }

    public function update(Request $request, string $resource, string $record): RedirectResponse
    {
        $this->adminCrudService->update($resource, $record, $request->all());

        return redirect()
            ->route('admin.resources.index', ['resource' => $resource])
            ->with('status', '更新成功');
    }
}
