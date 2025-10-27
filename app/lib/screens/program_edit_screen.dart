import 'package:flutter/material.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import '../models/user.dart';

class ProgramEditScreen extends StatefulWidget {
  final User user;
  final Program? program; // null for new program

  const ProgramEditScreen({
    Key? key,
    required this.user,
    this.program,
  }) : super(key: key);

  @override
  State<ProgramEditScreen> createState() => _ProgramEditScreenState();
}

class _ProgramEditScreenState extends State<ProgramEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late List<Exercise> _exercises;
  late bool _isTemplate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.program?.name ?? '');
    _descriptionController = TextEditingController(text: widget.program?.description ?? '');
    _exercises = widget.program?.exercises.toList() ?? [];
    _isTemplate = false; // TODO: Get from program data
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addExercise() {
    showDialog(
      context: context,
      builder: (context) => _ExerciseEditorDialog(
        onSave: (exercise) {
          setState(() {
            _exercises.add(exercise);
          });
        },
      ),
    );
  }

  void _editExercise(int index) {
    showDialog(
      context: context,
      builder: (context) => _ExerciseEditorDialog(
        exercise: _exercises[index],
        onSave: (exercise) {
          setState(() {
            _exercises[index] = exercise;
          });
        },
      ),
    );
  }

  void _deleteExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _importProgram() {
    showDialog(
      context: context,
      builder: (context) => _ImportProgramDialog(
        onImport: (program) {
          setState(() {
            _nameController.text = program.name;
            _descriptionController.text = program.description;
            _exercises = program.exercises.toList();
          });
        },
      ),
    );
  }

  void _saveProgram() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save to backend
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);
    final isAdmin = !widget.user.isStudent;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: burgundy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.program == null ? 'Create Program' : 'Edit Program',
          style: TextStyle(color: burgundy),
        ),
        actions: [
          TextButton(
            onPressed: _saveProgram,
            child: Text(
              'Save',
              style: TextStyle(
                color: burgundy,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info Section
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Program Name',
                              hintText: 'e.g. Tai Ji Walking Meditation',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a program name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Brief description of the program',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              value: _isTemplate,
                              onChanged: (value) {
                                setState(() {
                                  _isTemplate = value ?? false;
                                });
                              },
                              title: const Text('Program Template'),
                              subtitle: const Text(
                                'Make this available as a template for all users',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: burgundy,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Import Section
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Import from Template',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _importProgram,
                              icon: const Icon(Icons.file_download),
                              label: const Text('Import from My Programs or Templates'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: burgundy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Exercises Section
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Exercises',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addExercise,
                                icon: Icon(Icons.add, color: burgundy),
                                label: Text(
                                  'Add Exercise',
                                  style: TextStyle(color: burgundy),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_exercises.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.fitness_center,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No exercises yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add exercises to build your program',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _exercises.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) {
                                    newIndex--;
                                  }
                                  final exercise = _exercises.removeAt(oldIndex);
                                  _exercises.insert(newIndex, exercise);
                                });
                              },
                              itemBuilder: (context, index) {
                                final exercise = _exercises[index];
                                return _buildExerciseItem(
                                  exercise,
                                  index,
                                  key: ValueKey(exercise.name + index.toString()),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem(Exercise exercise, int index, {required Key key}) {
    const burgundy = Color(0xFF9B1C1C);

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_handle, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: burgundy.withValues(alpha: 0.1),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: burgundy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        title: Text(exercise.name),
        subtitle: Text(exercise.displayDuration),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: burgundy),
              onPressed: () => _editExercise(index),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade400),
              onPressed: () => _deleteExercise(index),
            ),
          ],
        ),
      ),
    );
  }
}

// Exercise Editor Dialog
class _ExerciseEditorDialog extends StatefulWidget {
  final Exercise? exercise;
  final Function(Exercise) onSave;

  const _ExerciseEditorDialog({
    this.exercise,
    required this.onSave,
  });

  @override
  State<_ExerciseEditorDialog> createState() => _ExerciseEditorDialogState();
}

class _ExerciseEditorDialogState extends State<_ExerciseEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  late TextEditingController _repetitionsController;
  late TextEditingController _restController;
  late ExerciseType _selectedType;
  late bool _hasSides;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise?.name ?? '');
    _descriptionController = TextEditingController(text: widget.exercise?.description ?? '');
    _durationController = TextEditingController(
      text: widget.exercise?.durationSeconds?.toString() ?? '60',
    );
    _repetitionsController = TextEditingController(
      text: widget.exercise?.repetitions?.toString() ?? '10',
    );
    _restController = TextEditingController(
      text: widget.exercise?.restAfterSeconds.toString() ?? '30',
    );
    _selectedType = widget.exercise?.type ?? ExerciseType.timed;
    _hasSides = widget.exercise?.hasSides ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _repetitionsController.dispose();
    _restController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final exercise = Exercise(
        id: widget.exercise?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        type: _selectedType,
        durationSeconds: _selectedType != ExerciseType.repetition
            ? int.tryParse(_durationController.text)
            : null,
        repetitions: _selectedType != ExerciseType.timed
            ? int.tryParse(_repetitionsController.text)
            : null,
        hasSides: _hasSides,
        restAfterSeconds: int.tryParse(_restController.text) ?? 0,
      );
      widget.onSave(exercise);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.exercise == null ? 'Add Exercise' : 'Edit Exercise',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: burgundy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Exercise Name',
                      hintText: 'e.g. Horse Stance',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an exercise name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<ExerciseType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Exercise Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ExerciseType.timed,
                        child: Text('Timed (Duration)'),
                      ),
                      DropdownMenuItem(
                        value: ExerciseType.repetition,
                        child: Text('Repetition (Count)'),
                      ),
                      DropdownMenuItem(
                        value: ExerciseType.combined,
                        child: Text('Combined (Both)'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_selectedType != ExerciseType.repetition)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (seconds)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter duration';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),

                  if (_selectedType != ExerciseType.timed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _repetitionsController,
                        decoration: const InputDecoration(
                          labelText: 'Repetitions',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter repetitions';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),

                  TextFormField(
                    controller: _restController,
                    decoration: const InputDecoration(
                      labelText: 'Rest After (seconds)',
                      hintText: '0 for no rest',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  CheckboxListTile(
                    value: _hasSides,
                    onChanged: (value) {
                      setState(() {
                        _hasSides = value ?? false;
                      });
                    },
                    title: const Text('Both Sides'),
                    subtitle: const Text('Exercise needs to be done on both sides'),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: burgundy,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: burgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        widget.exercise == null ? 'Add Exercise' : 'Save Changes',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Import Program Dialog
class _ImportProgramDialog extends StatefulWidget {
  final Function(Program) onImport;

  const _ImportProgramDialog({required this.onImport});

  @override
  State<_ImportProgramDialog> createState() => _ImportProgramDialogState();
}

class _ImportProgramDialogState extends State<_ImportProgramDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Program? _selectedProgram;

  // Mock data - will be replaced with real data from backend
  final List<_ProgramListItem> _mockPrograms = [
    _ProgramListItem(
      program: Program.getMockProgram(),
      isTemplate: true,
    ),
    _ProgramListItem(
      program: Program(
        id: '2',
        name: 'Evening Qi Gong',
        description: 'Relaxing evening practice',
        exercises: [],
      ),
      isTemplate: true,
    ),
    _ProgramListItem(
      program: Program(
        id: '3',
        name: 'Ba Gua Circle Walking',
        description: 'Single palm change meditation walk',
        exercises: [],
      ),
      isTemplate: false,
    ),
  ];

  List<_ProgramListItem> get _filteredPrograms {
    if (_searchQuery.isEmpty) {
      return _mockPrograms;
    }
    return _mockPrograms.where((item) {
      return item.program.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.program.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const burgundy = Color(0xFF9B1C1C);

    return Dialog(
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Import Program',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search programs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Program list
            Expanded(
              child: ListView.builder(
                itemCount: _filteredPrograms.length,
                itemBuilder: (context, index) {
                  final item = _filteredPrograms[index];
                  final program = item.program;
                  final isSelected = _selectedProgram?.id == program.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? burgundy.withValues(alpha: 0.1)
                          : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? burgundy
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _selectedProgram = program;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          program.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? burgundy : Colors.black,
                                          ),
                                        ),
                                        if (item.isTemplate) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: burgundy.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'TEMPLATE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: burgundy,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      program.description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${program.exercises.length} exercises',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: burgundy, size: 28),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedProgram == null
                    ? null
                    : () {
                        widget.onImport(_selectedProgram!);
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: burgundy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Text(
                  _selectedProgram == null
                      ? 'Select a program to import'
                      : 'Import "${_selectedProgram!.name}"',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Helper class for program list with template flag
class _ProgramListItem {
  final Program program;
  final bool isTemplate;

  _ProgramListItem({
    required this.program,
    required this.isTemplate,
  });
}
