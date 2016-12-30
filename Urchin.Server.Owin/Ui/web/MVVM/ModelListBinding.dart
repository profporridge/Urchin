﻿import 'Events.dart';
import 'Types.dart';
import 'ViewModel.dart';
import 'Model.dart';
import 'Enums.dart';
import 'Events.dart';

// Provides two-way data binding to a list of models
// The binding is associated with a single list of models
// and many UI list elements. A view model is basically a collection
// of these PropertyBinding<T> and ModelListBinding<T> objects that connect the 
// views to the models.
class ModelListBinding<TM extends Model, TVM extends ViewModel>
{
	// Defines how to create new models
	ModelFactory<TM> modelFactory;
	
	// Defines how to create new view models
	ViewModelFactory<TM, TVM> viewModelFactory;
  
	// Raised after a new model is added to the list
	SubscriptionEvent<ListEvent> onAdd = new SubscriptionEvent<ListEvent>();
	
	// Raised after a model is flagged for deletion. Most views should hide deleted records
	SubscriptionEvent<ListEvent> onDelete = new SubscriptionEvent<ListEvent>();

	// Raised when the whole list of models is replaced with a new one
	SubscriptionEvent<ListEvent> onListChanged = new SubscriptionEvent<ListEvent>();
  
	List<TVM> viewModels;

	ModelListBinding(this.modelFactory, this.viewModelFactory, [List<TM> models])
	{
		viewModels = new List<TVM>();
		this.models = models;
	}
  
	List<TM> _models;
	List<TM> get models => _models;

	void set models(List<TM> value)
	{
		for (TVM viewModel in viewModels)
		{
			viewModel.dispose();
		}
		viewModels.clear();
      
		_models = value;

		if (value != null)
		{
			for (int index = 0; index < value.length; index++)
			{
				TVM viewModel = viewModelFactory(value[index]);
				viewModels.add(viewModel);
			}
		}
		onListChanged.raise(new ListEvent(-1));
	}
  
    // Call this to add a new model to the end of the list
	TVM add()
	{
		if (modelFactory == null)
			return null;

		return addModel(modelFactory(null));
	}

    // Call this to add a new model to the end of the list
	TVM addModel(TM model)
	{
		if (_models == null)
			throw 'No list of models to add to';

		int index = models.length;

		models.add(model);
      
		TVM viewModel = viewModelFactory(model);
		viewModel.added();
		viewModels.add(viewModel);
      
		onAdd.raise(new ListEvent(index));

		return viewModel;
	}
  
	// Call this to mark a model for deletion upon save
	void delete(int index)
	{
		TVM viewModel = viewModels[index];

		if (viewModel.getState() == ChangeState.added)
		{
			viewModels.removeAt(index);
			models.removeAt(index);
			viewModel.dispose();
			onListChanged.raise(new ListEvent(-1));
		}
		else
		{
			viewModel.deleted();
			onDelete.raise(new ListEvent(index));
		}
	}

	// Call this before saving changes to remove deleted models from the list
	void saving()
	{
		if (models != null)
		{
			for (var index = viewModels.length - 1; index >= 0; index--)
			{
				var viewModel = viewModels[index];
				if (viewModel.getState() == ChangeState.deleted)
				{
					models.removeAt(index);
					viewModels.removeAt(index);
					viewModel.dispose();
				}
				else
				{
					viewModel.saving();
				}
			}
		}
	}

	// Call this ater saving changes to mark all the view models as saved
	void saved()
	{
		viewModels.forEach((ViewModel vm) => vm.saved());
	}

	// Calculates the modification status of this list of models
	ChangeState getState()
	{
		for (TVM viewModel in viewModels)
		{
			var state = viewModel.getState();
			if (state != ChangeState.unmodified)
				return ChangeState.modified;
		}
		return ChangeState.unmodified;
	}

}
