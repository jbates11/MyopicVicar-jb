# Code Fixes for Missing `show` Action

---

## Quick Fix (5 minutes)

### Option A: Add the Missing `show` Method (Recommended)

**File:** `/app/controllers/emendation_types_controller.rb`

**Current Code (Lines 17-30):**
```ruby
  before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]

  def index
    @emendation_types = EmendationType.all
  end

  def new
    @emendation_type = EmendationType.new
  end

  def create
```

**Fixed Code (Add show method after new):**
```ruby
  before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]

  def index
    @emendation_types = EmendationType.all
  end

  def new
    @emendation_type = EmendationType.new
  end

  def show
    # Instance variable @emendation_type is automatically loaded
    # by the before_action :set_emendation_type hook above.
    # Rails will render app/views/emendation_types/show.html.erb
  end

  def create
```

**What to do:**
1. Open `/app/controllers/emendation_types_controller.rb`
2. Add the `show` method after `new` method (around line 23)
3. Save the file
4. Restart Rails server
5. Test by visiting: `http://localhost:3000/emendation_types/1`

---

### Option B: Remove `show` from Routes (If You Don't Need It)

**File:** `/config/routes.rb`

**Current Code (Line 570):**
```ruby
  resources :emendation_types
```

**Fixed Code:**
```ruby
  resources :emendation_types, except: [:show]
```

**What this does:**
- Creates all standard routes EXCEPT the show route
- GET /emendation_types (index) ✓ Works
- GET /emendation_types/new (new) ✓ Works
- POST /emendation_types (create) ✓ Works
- GET /emendation_types/:id (show) ✗ Removed
- GET /emendation_types/:id/edit (edit) ✓ Works
- PATCH /emendation_types/:id (update) ✓ Works
- DELETE /emendation_types/:id (destroy) ✓ Works

**When to use this:**
- If users never need to view a single emendation type in detail
- If you only need a list view

---

## Full Fix with View Template

If you want users to be able to view an individual emendation type, you also need a view template.

### Step 1: Add the Controller Action

**File:** `/app/controllers/emendation_types_controller.rb`

Add after the `new` method:
```ruby
  def show
    # @emendation_type is loaded by before_action :set_emendation_type
  end
```

### Step 2: Create the View Template

**File:** `/app/views/emendation_types/show.html.erb`

Create this new file with:
```erb
<div class="container">
  <h1><%= @emendation_type.name %></h1>
  
  <div class="details">
    <p>
      <strong>Target Field:</strong>
      <%= @emendation_type.target_field %>
    </p>
    
    <p>
      <strong>Origin:</strong>
      <%= @emendation_type.origin %>
    </p>
  </div>
  
  <div class="actions">
    <%= link_to "Edit", edit_emendation_type_path(@emendation_type), class: "btn btn-primary" %>
    <%= link_to "Delete", emendation_type_path(@emendation_type), method: :delete, 
        data: { confirm: "Are you sure?" }, class: "btn btn-danger" %>
    <%= link_to "Back to List", emendation_types_path, class: "btn btn-secondary" %>
  </div>
</div>
```

**Note:** Adjust the HTML/styling to match your template (FreeBMD, FreeCEN, or FreeREG).

---

## Checking for the EmendationRulesController Issue

You mentioned an error about `EmendationRulesController#show`. Let me check if that controller has the same problem:

### EmendationRulesController Status

**File:** `/app/controllers/emendation_rules_controller.rb`

This controller **ALSO** declares `show` in before_action but doesn't define it:

```ruby
class EmendationRulesController < ApplicationController

  before_action :set_emendation_rule, only: [:show, :edit, :update, :destroy]
  #              ↑ Declares show, edit, update, destroy exist

  # ... index, new, create methods exist ...
  
  # But show, edit, update methods are defined!
  def edit
    # This exists ✓
  end

  def update
    # This exists ✓
  end

  def destroy
    # This exists ✓
  end

  # ⚠️ But show is MISSING!

end
```

**Fix for EmendationRulesController:**

Add this method after the `destroy` method but before `private`:

```ruby
  def show
    # @emendation_rule is loaded by before_action :set_emendation_rule
  end
```

---

## Root Cause Analysis: Why This Happened

### The Problem Pattern

```ruby
# ❌ WRONG: Declaring actions in before_action but not defining them
before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]
#                                          ↑ Promising all four exist

def new
end

def create
end

# ✓ edit, update, destroy are defined below
# ❌ show is NOT defined!
```

### Why It Works for Some Actions

The `edit`, `update`, and `destroy` methods ARE defined:
```ruby
def edit      # ✓ EXISTS
  # ...
end

def update    # ✓ EXISTS
  # ...
end

def destroy   # ✓ EXISTS
  # ...
end
```

But `show` is missing:
```ruby
def show      # ❌ MISSING
  # ... this method was never created
end
```

---

## Step-by-Step Testing Procedure

After implementing the fix, test it:

### Test 1: Verify Server Restarts
```bash
# In terminal, stop the current server (Ctrl+C)
# Then restart:
rails s
# Should start without errors
```

### Test 2: Create a Test Record
1. Visit: `http://localhost:3000/emendation_types`
2. Click "New" or similar button
3. Fill in: Name, Target Field, Origin
4. Click "Create"
5. Should redirect to index page showing the new type

### Test 3: View Individual Record
1. Click on the type you just created (or the name in the list)
2. Should navigate to: `http://localhost:3000/emendation_types/1` (or similar ID)
3. Should display the details correctly

### Test 4: Check Console for Errors
Open browser developer console (F12):
- JavaScript tab: Should show no errors
- Network tab: All requests should be 200/302/404 (not 500)

---

## Before/After Code Comparison

### EmendationTypesController

**BEFORE (Broken):**
```ruby
class EmendationTypesController < ApplicationController
  before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]

  def index
    @emendation_types = EmendationType.all
  end

  def new
    @emendation_type = EmendationType.new
  end

  # ... create, edit, update, destroy ...
  
  # ❌ Missing: show method
end
```

**AFTER (Fixed):**
```ruby
class EmendationTypesController < ApplicationController
  before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]

  def index
    @emendation_types = EmendationType.all
  end

  def new
    @emendation_type = EmendationType.new
  end

  def show
    # @emendation_type loaded by before_action
  end

  # ... create, edit, update, destroy ...
end
```

---

## Best Practices to Prevent This in Future

### 1. Match before_action to Defined Methods

**Golden Rule:** Only list actions in `before_action` that you actually define.

```ruby
# ❌ WRONG: Listing actions you don't define
before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]
def edit; end
def update; end
def destroy; end
# Missing: show

# ✅ RIGHT: Only list actions you define
before_action :set_emendation_type, only: [:edit, :update, :destroy]
# or
before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]
def show; end      # ← Define this
def edit; end
def update; end
def destroy; end
```

### 2. Use Standard RESTful Actions

If using `resources :model`, implement these seven actions:
```ruby
def index      # List all
def new        # Show form for new
def create     # Save new
def show       # Show one
def edit       # Show edit form
def update     # Save changes
def destroy    # Delete
```

### 3. If Not Implementing All Actions, Use `except`

```ruby
# Option A: In routes
resources :emendation_types, except: [:show]

# Option B: In controller (if you must)
before_action :set_model, only: [:edit, :update, :destroy]
# Don't include :show if you won't define it
```

### 4. Run Tests

RSpec tests would catch this immediately:

```ruby
# spec/controllers/emendation_types_controller_spec.rb
describe EmendationTypesController do
  describe "GET #show" do
    it "should return 200 status" do
      emendation_type = create(:emendation_type)
      get :show, params: { id: emendation_type.id }
      expect(response).to have_http_status(200)
    end
  end
end
```

Running this would fail with the error you're seeing, alerting you immediately.

---

## Summary Table

| Issue | Solution | File | Difficulty |
|-------|----------|------|------------|
| Missing `show` method | Add method | `/app/controllers/emendation_types_controller.rb` | Easy |
| Don't want `show` route | Use `except:` in routes | `/config/routes.rb` | Easy |
| Same issue in EmendationRulesController | Add method | `/app/controllers/emendation_rules_controller.rb` | Easy |
| Want to display details | Create view template | `/app/views/emendation_types/show.html.erb` | Medium |

---

## Recommended Action

**For this codebase:**

1. ✅ Add `show` method to `EmendationTypesController`
2. ✅ Add `show` method to `EmendationRulesController`  
3. ✅ Create `show.html.erb` view template
4. ✅ Test by visiting individual records
5. ✅ Run RSpec tests to verify

This is the most complete solution that follows Rails conventions.

