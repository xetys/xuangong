  Future<void> _saveProgram() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one exercise'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Update exercise order indices
      for (int i = 0; i < _exercises.length; i++) {
        _exercises[i] = Exercise(
          id: _exercises[i].id,
          programId: _exercises[i].programId,
          name: _exercises[i].name,
          description: _exercises[i].description,
          orderIndex: i,
          type: _exercises[i].type,
          durationSeconds: _exercises[i].durationSeconds,
          repetitions: _exercises[i].repetitions,
          restAfterSeconds: _exercises[i].restAfterSeconds,
          hasSides: _exercises[i].hasSides,
          sideDurationSeconds: _exercises[i].sideDurationSeconds,
          metadata: _exercises[i].metadata,
        );
      }

      final program = Program(
        id: widget.program?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
        exercises: _exercises,
        isTemplate: _isTemplate,
        isPublic: _isTemplate, // Templates are public by default
      );

      if (widget.program == null) {
        // Create new program with exercises
        await _programService.createProgram(program);
      } else {
        // Update existing program with exercises
        await _programService.updateProgram(widget.program!.id, program);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Program saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save program: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
