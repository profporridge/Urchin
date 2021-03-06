﻿part of mvvm;

abstract class ViewModel
{
	ChangeState _state;
	bool _removeBeforeSave;

	ViewModel([bool this._removeBeforeSave = true])
	{
		_state = ChangeState.added;
	}

	void dispose()
	{
	}

	void reload()
	{
	}

	// Indicates that the view model should be deleted when changes are saved back to the server
	void deleted()
	{
		if (_state == ChangeState.added)
			_state = ChangeState.unmodified;
		else if (_state == ChangeState.unmodified)
			_state = ChangeState.deleted;
	}

	// Indicates that the view model has changes that need to be persisted to the server
	void modified()
	{
		if (_state == ChangeState.unmodified)
			_state = ChangeState.modified;
	}

	// Indicates that this is a new record that does not exist on the server
	void added()
	{
		_state = ChangeState.added;
	}

	// Indicates that all changes have been saved to the server
	void saved()
	{
		if (_state != ChangeState.deleted)
		{
			_state = ChangeState.unmodified;
			_forEachChild((ViewModel vm) => vm.saved());
			_forEachModelList((ModelList l) => l.saved());
		}
	}

	// Indicates that the underlying models were populated from the server and any pending changes should be ignored
	void loaded()
	{
		_state = ChangeState.unmodified;
		_forEachChild((ViewModel vm) => vm.loaded());
		_forEachModelList((ModelList l) => l.loaded());
	}

	// Override this in derrived classes to provide a list of other view models
	// that come into play when figuring out the change state of this view model
	List<ViewModel> getChildViewModels()
	{
		return null;
	}

	// Override this in derrived classes to provide a list of the bound lists
	// of child models that are managed by this view model. This will ensure that
	// the change status of these view model lists will be maintained.
	List<ModelList> getModelLists()
	{
		return null;
	}

	void _forEachChild(void f(ViewModel vm))
	{
		List<ViewModel> children = getChildViewModels();
		if (children != null)
			children.forEach((ViewModel vm) { if (vm != null) f(vm); });
	}

	void _forEachModelList(void f(ModelList modelList))
	{
		List<ModelList> modelLists = getModelLists();
		if (modelLists != null)
			modelLists.forEach((ModelList l) { if (l != null) f(l); });
	}

	// Call this proir to saving to update the models from the view models
	void saving()
	{
		_forEachChild((ViewModel vm) => vm.saving());
		_forEachModelList((ModelList l) => l.saving());
	}

	// Saves this view model back to the server.
	// Changes it's state back to unmodified unless it is deleted
	Future<SaveResult> save([bool alert = true]) async
	{
		try
		{
			var state = getState();

			if (state == ChangeState.unmodified)
			{
				if (alert) MvvmEvents.alert.raise('There are no changes to save');
				return SaveResult.unmodified;
			}

			saving();

			var result = await saveChanges(state, alert);

			if (result == SaveResult.saved)
				saved();

			return result;
		}
		catch (e)
		{
			MvvmEvents.alert.raise(e.toString());
			return SaveResult.failed;
		}
	}

	// Override in derrived classes to save changes in this view model back to the server
	// The default behaviour in this base class is to save all the child view models and
	// remove the deleted view models after saving it complete
	Future<SaveResult> saveChanges(ChangeState state, bool alert) async
	{
		SaveResult result = SaveResult.saved;

		List<ViewModel> children = getChildViewModels();
		if (children != null)
		{
			for (ViewModel child in children)
			{ 
				if (child != null) 
				{
					SaveResult childResult = await child.saveChanges(child.getState(), false);
					if (childResult == SaveResult.failed)
						result = childResult;
					else if (childResult == SaveResult.saved)
						child.saved();
				}
			}
		}

		List<ModelList> modelLists = getModelLists();
		if (modelLists != null)
		{
			for (ModelList list in modelLists)
			{
				if (list != null)
				{
					if (_removeBeforeSave)
						list.removeDeleted();

					SaveResult listResult = await list.saveChanges();

					if (listResult == SaveResult.failed)
					{
						result = listResult;
					}
					else if (listResult == SaveResult.saved)
					{
						if (!_removeBeforeSave)
							list.removeDeleted();
						list.saved();
					}
				}
			}
		}
		
		if (alert)
		{
			if (result == SaveResult.saved)
				MvvmEvents.alert.raise('Saved changes to ' + toString());
			else if (result == SaveResult.notsaved)
				MvvmEvents.alert.raise('Did not save changes to ' + toString());
			else if (result == SaveResult.failed)
				MvvmEvents.alert.raise('Failed to save changes to ' + toString());
			else if (result == SaveResult.unmodified)
				MvvmEvents.alert.raise('No changes to ' + toString() + ' to save');
		}
		return result;
	}

	void removeDeleted()
	{
		_forEachModelList((ModelList modelList) => modelList.removeDeleted());
	}

	void undelete()
	{
		if (getState() == ChangeState.deleted)
			_state = ChangeState.unmodified;

		_forEachChild((ViewModel vm) => vm.undelete());
		_forEachModelList((ModelList modelList) => modelList.undelete());
	}

	// Gets the current state of this view model and all of its children
	ChangeState getState()
	{
		if (_state != ChangeState.unmodified)
		{
			return _state;
		}

		List<ViewModel> children = getChildViewModels();
		if (children != null && children.length > 0)
		{
			for (ViewModel child in children)
			{
				if (child != null)
				{
					ChangeState childState = child.getState();
					if (childState != ChangeState.unmodified)
					{
						return ChangeState.modified;
					}
				}
			}
		}

		List<ModelList> modelLists = getModelLists();
		if (modelLists != null && modelLists.length > 0)
		{
			for (ModelList modelList in modelLists)
			{
				if (modelList != null)
				{
					ChangeState listState = modelList.getState();
					if (listState != ChangeState.unmodified)
					{
						return ChangeState.modified;
					}
				}
			}
		}

		return ChangeState.unmodified;
	}

}