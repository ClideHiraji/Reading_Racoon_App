<?php

namespace Tests\Feature\Admin;

use Illuminate\Support\Facades\Route;

/**
 * A missing or weak ADMIN_PATH turns the portal off entirely (D-013).
 */
class AdminPortalDisabledTest extends AdminTestCase
{
    protected function adminPathForTest(): string
    {
        return 'admin-too-short';
    }

    public function test_a_short_admin_path_registers_no_admin_routes(): void
    {
        $this->assertFalse(Route::has('admin.login'));
        $this->get($this->admin())->assertNotFound();
        $this->post($this->admin(), ['email' => 'a', 'password' => 'b', 'code' => '1'])->assertNotFound();
    }
}
